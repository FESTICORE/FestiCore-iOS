import ComposableArchitecture
import FestivalDomainInterface
import FestiCorePackInterface
import Foundation

@Reducer
public struct HomeFeature {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalSelectionStore) private var selectionStore
  @Dependency(\.festivalBookedStore) private var bookedStore
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.homeImagePrefetchClient) private var imagePrefetchClient
  @Dependency(\.homeLiveActivityClient) private var liveActivityClient
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

  public init() {}

  @ObservableState
  public struct State: Equatable {
    public enum ViewState: Equatable {
      case loading
      case loaded
    }

    public var viewState: ViewState = .loading
    public var catalog: IdentifiedArrayOf<FestivalCatalogItem> = []
    public var cachedPacks: [String: CachedFestivalPack] = [:]
    public var imageURLs: [String: URL] = [:]
    public var imageRevision = 0
    public var imageRetryPending = false
    public var packWatchFailed = false
    public var selectedFestivalID: String?
    public var bookedFestivalIDs: Set<String> = []
    public var selectedPack: FestivalPackDocument?
    public var connection: Connection = .loading
    public var hasStarted = false
    public var isForeground = true
    public var catalogCacheReadFailed = false
    public var packCacheReadFailed = false
    var liveActivities: [String: HomeLiveActivityRecord] = [:]
    var liveActivityReady = false
    var liveActivityBusyFestivalID: String?
    var liveActivityError: String?
    var liveActivityNow: Date = .distantPast
    var liveActivityRevision = 0

    public var cacheReadFailed: Bool {
      catalogCacheReadFailed || packCacheReadFailed
    }

    public init(selectedFestivalID: String? = nil) {
      self.selectedFestivalID = selectedFestivalID
    }

    public var festivals: [FestivalOverview] {
      var result = catalog.map { FestivalOverview(item: $0, isCached: cachedPacks[$0.id] != nil) }
      let known = Set(result.map(\.id))
      result += cachedPacks.values
        .filter { !known.contains($0.festivalID) }
        .compactMap(FestivalOverview.init(pack:))
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      return result
    }

    public var selectedFestival: FestivalOverview? {
      festivals.first { $0.id == selectedFestivalID }
    }

    var liveActivityState: LiveActivityControlState {
      guard let festival = selectedFestival else {
        return .init(title: "Live Activity 사용 불가", isEnabled: false, message: nil)
      }
      if liveActivityBusyFestivalID != nil {
        return .init(title: "처리 중", isEnabled: false, message: nil)
      }
      if !liveActivityReady {
        return .init(title: "Live Activity 준비 중", isEnabled: false, message: nil)
      }
      if liveActivities[festival.id] != nil {
        return .init(title: "Live Activity 끄기", isEnabled: true, message: liveActivityError)
      }
      guard let schedule = FestivalLiveActivitySchedule.resolve(
        festival: festival,
        pack: pack(for: festival.id),
        now: liveActivityNow
      ) else {
        return .init(title: "Live Activity 사용 불가", isEnabled: false, message: "축제 일정이 필요합니다.")
      }
      return .init(
        title: "Live Activity 켜기",
        isEnabled: schedule.canStart,
        message: liveActivityError ?? (schedule.phase == .finished
          ? "종료된 축제입니다."
          : schedule.canStart ? nil : "축제 시작 2시간 전부터 사용할 수 있습니다.")
      )
    }

    func pack(for festivalID: String) -> FestivalPackDocument? {
      if selectedFestivalID == festivalID { return selectedPack }
      guard let cached = cachedPacks[festivalID] else { return nil }
      return try? JSONDecoder().decode(FestivalPackDocument.self, from: cached.pack)
    }

    public func imageURL(for value: String?) -> URL? {
      value.flatMap { imageURLs[$0] }
    }
  }

  public enum Connection: Equatable {
    case loading
    case cached
    case connecting
    case reconnecting
    case live
    case offline
    case unavailable
  }

  struct LiveActivityControlState: Equatable {
    let title: String
    let isEnabled: Bool
    let message: String?
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case inner(InnerAction)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case foregroundChanged(Bool)
    case refreshRequested
    case selectFestival(String)
    case toggleBookedFestival(String)
    case liveActivityOnAppear
    case liveActivityTapped
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case cachedLoaded([FestivalCatalogItem], [CachedFestivalPack], String?, Bool, Bool)
    case catalogRefreshed([FestivalCatalogItem])
    case catalogFailed
    case packReceived(String, PackSyncResult)
    case packFailed(String)
    case liveActivitiesLoaded([HomeLiveActivityRecord], Int)
    case liveActivityStarted(HomeLiveActivityRecord)
    case liveActivityUpdated(HomeLiveActivityRecord)
    case liveActivityStopped(String, String)
    case liveActivityFailed(String)
    case liveActivityBoundary
    case liveActivityChanged
  }

  private enum CancelID { case packUpdates, imagePrefetch, liveActivityChanges, liveActivityBoundary }
  private struct LiveActivitySyncID: Hashable { let id: String }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard !state.hasStarted else { return .none }
        state.hasStarted = true
        state.bookedFestivalIDs = bookedStore.load()
        return .run { send in
          async let catalog = try? catalogService.cachedFestivals()
          async let packs = try? packService.cachedPacks()
          let cachedCatalog = await catalog
          let cachedPacks = await packs
          await send(.inner(.cachedLoaded(
            cachedCatalog ?? [], cachedPacks ?? [], selectionStore.load(),
            cachedCatalog == nil, cachedPacks == nil
          )))
        }

      case .view(.liveActivityOnAppear):
        return .merge(loadLiveActivities(revision: state.liveActivityRevision), watchLiveActivityChanges())

      case .view(.liveActivityTapped):
        guard state.liveActivityReady,
              let festival = state.selectedFestival,
              state.liveActivityBusyFestivalID == nil else { return .none }
        state.liveActivityNow = date.now
        state.liveActivityError = nil
        if let existing = state.liveActivities[festival.id] {
          state.liveActivityBusyFestivalID = festival.id
          state.liveActivityRevision += 1
          return .run { send in
            await liveActivityClient.end(existing.id)
            await send(.inner(.liveActivityStopped(festival.id, existing.id)))
          }
        }
        guard let schedule = FestivalLiveActivitySchedule.resolve(
          festival: festival, pack: state.pack(for: festival.id), now: state.liveActivityNow
        ), schedule.canStart else { return .none }
        state.liveActivityBusyFestivalID = festival.id
        state.liveActivityRevision += 1
        return .run { send in
          do {
            let id = try await liveActivityClient.start(
              festival.id, festival.name, schedule.startDate, schedule.endDate, schedule.phase
            )
            await liveActivityClient.update(
              id, schedule.phase, schedule.startDate, schedule.endDate
            )
            await send(.inner(.liveActivityStarted(.init(
              id: id, festivalID: festival.id, phase: schedule.phase,
              startDate: schedule.startDate, endDate: schedule.endDate
            ))))
          } catch {
            await send(.inner(.liveActivityFailed("Live Activity를 켤 수 없습니다. 설정을 확인해 주세요.")))
          }
        }

      case let .inner(.cachedLoaded(catalog, packs, savedID, catalogReadFailed, packReadFailed)):
        state.catalog = identifiedCatalog(catalog)
        state.cachedPacks = Dictionary(uniqueKeysWithValues: packs.map { ($0.festivalID, $0) })
        if !state.festivals.isEmpty { state.viewState = .loaded }
        state.catalogCacheReadFailed = catalogReadFailed
        state.packCacheReadFailed = packReadFailed
        let available = state.festivals
        state.selectedFestivalID = available.first { $0.id == state.selectedFestivalID }?.id
          ?? available.first { $0.id == savedID }?.id
          ?? available.first { $0.isCached }?.id
          ?? available.first { $0.packVersion > 0 }?.id
          ?? available.first?.id
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        return .merge(refreshCatalog(), watchSelectedPack(state), prefetchImages(state), syncLiveActivities(state))

      case .view(.refreshRequested):
        state.packWatchFailed = false
        return .merge(refreshCatalog(), watchSelectedPack(state))

      case let .view(.foregroundChanged(isForeground)):
        state.isForeground = isForeground
        guard state.hasStarted else {
          return isForeground ? .send(.view(.onAppear)) : prefetchImages(state)
        }
        if isForeground {
          state.packWatchFailed = false
          if state.liveActivityReady { state.liveActivityNow = date.now }
          return .merge(
            refreshCatalog(), watchSelectedPack(state), prefetchImages(state),
            state.liveActivityReady ? loadLiveActivities(revision: state.liveActivityRevision) : .none
          )
        }
        return .merge(
          .cancel(id: CancelID.packUpdates),
          .cancel(id: CancelID.liveActivityBoundary),
          prefetchImages(state)
        )

      case let .view(.selectFestival(id)):
        guard state.festivals.contains(where: { $0.id == id }) else { return .none }
        state.selectedFestivalID = id
        state.liveActivityError = nil
        if state.liveActivityReady { state.liveActivityNow = date.now }
        state.packWatchFailed = false
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        return .merge(
          .run { _ in selectionStore.save(id) },
          watchSelectedPack(state),
          prefetchImages(state),
          liveActivityBoundary(state)
        )


      case let .view(.toggleBookedFestival(id)):
        guard state.festivals.contains(where: { $0.id == id }) else { return .none }
        if !state.bookedFestivalIDs.insert(id).inserted {
          state.bookedFestivalIDs.remove(id)
        }
        let ids = state.bookedFestivalIDs
        return .run { _ in bookedStore.save(ids) }

      case let .inner(.catalogRefreshed(catalog)):
        state.viewState = .loaded
        if state.liveActivityReady { state.liveActivityNow = date.now }
        let previouslyAvailable = (state.selectedFestival?.packVersion ?? 0) > 0
        let restartFailedWatch = state.packWatchFailed
        state.packWatchFailed = false
        state.catalog = identifiedCatalog(catalog)
        retryImagesAfterRecovery(in: &state)
        state.catalogCacheReadFailed = false
        if state.selectedFestival == nil, let first = state.festivals.first(where: { $0.isCached || $0.packVersion > 0 }) ?? state.festivals.first {
          state.selectedFestivalID = first.id
          showCachedPack(in: &state)
          resolveImageURLs(in: &state)
          return .merge(watchSelectedPack(state), prefetchImages(state), syncLiveActivities(state))
        }
        resolveImageURLs(in: &state)
        if state.selectedPack == nil, state.selectedFestival?.packVersion == 0 {
          state.connection = .unavailable
        }
        let prefetch = prefetchImages(state)
        return (restartFailedWatch || !previouslyAvailable) && (state.selectedFestival?.packVersion ?? 0) > 0
          ? .merge(watchSelectedPack(state), prefetch, syncLiveActivities(state))
          : .merge(prefetch, syncLiveActivities(state))

      case .inner(.catalogFailed):
        state.viewState = .loaded
        if state.connection != .live {
          state.imageRetryPending = true
          state.connection = .offline
        }
        return .none

      case let .inner(.packReceived(id, result)):
        guard state.selectedFestivalID == id else { return .none }
        switch result {
        case let .updated(pack), let .notModified(pack):
          let previousPack = state.selectedPack
          state.cachedPacks[id] = pack
          if let document = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack) {
            state.selectedPack = document
            state.connection = .live
            state.packWatchFailed = false
            state.packCacheReadFailed = false
            let retryPending = state.imageRetryPending
            retryImagesAfterRecovery(in: &state)
            resolveImageURLs(in: &state)
            return previousPack != document || retryPending
              ? .merge(prefetchImages(state), syncLiveActivities(state))
              : .none
          } else {
            state.connection = state.selectedPack == nil ? .unavailable : .cached
          }
        case .retryAfter:
          state.connection = state.selectedPack == nil ? .connecting : .cached
        case .reconnecting:
          state.connection = .reconnecting
          state.imageRetryPending = true
        }
        return .none

      case let .inner(.packFailed(id)):
        guard state.selectedFestivalID == id else { return .none }
        state.imageRetryPending = true
        state.packWatchFailed = true
        state.connection = .offline
        return .none

      case let .inner(.liveActivitiesLoaded(activities, revision)):
        guard revision == state.liveActivityRevision else {
          return loadLiveActivities(revision: state.liveActivityRevision)
        }
        state.liveActivityReady = true
        state.liveActivityNow = date.now
        var current: [String: HomeLiveActivityRecord] = [:]
        for activity in activities where current[activity.festivalID] == nil {
          current[activity.festivalID] = activity
        }
        if let busyID = state.liveActivityBusyFestivalID {
          current[busyID] = state.liveActivities[busyID]
        }
        state.liveActivities = current
        return syncLiveActivities(state)

      case let .inner(.liveActivityStarted(activity)):
        state.liveActivityBusyFestivalID = nil
        state.liveActivityRevision += 1
        state.liveActivities[activity.festivalID] = activity
        return liveActivityBoundary(state)

      case let .inner(.liveActivityUpdated(activity)):
        guard state.liveActivities[activity.festivalID]?.id == activity.id else { return .none }
        state.liveActivities[activity.festivalID] = activity
        return .none

      case let .inner(.liveActivityStopped(festivalID, activityID)):
        if state.liveActivityBusyFestivalID == festivalID {
          state.liveActivityBusyFestivalID = nil
        }
        state.liveActivityRevision += 1
        if state.liveActivities[festivalID]?.id == activityID {
          state.liveActivities.removeValue(forKey: festivalID)
        }
        return liveActivityBoundary(state)

      case let .inner(.liveActivityFailed(message)):
        state.liveActivityBusyFestivalID = nil
        state.liveActivityRevision += 1
        state.liveActivityError = message
        return .none

      case .inner(.liveActivityBoundary):
        state.liveActivityNow = date.now
        return syncLiveActivities(state)

      case .inner(.liveActivityChanged):
        return loadLiveActivities(revision: state.liveActivityRevision)
      }
    }
  }

  private func refreshCatalog() -> Effect<Action> {
    .run { send in
      do { await send(.inner(.catalogRefreshed(try await catalogService.refresh()))) }
      catch { await send(.inner(.catalogFailed)) }
    }
  }

  private func loadLiveActivities(revision: Int) -> Effect<Action> {
    .run { send in
      await send(.inner(.liveActivitiesLoaded(await liveActivityClient.activities(), revision)))
    }
  }

  private func watchLiveActivityChanges() -> Effect<Action> {
    .run { send in
      for await _ in liveActivityClient.changes() {
        await send(.inner(.liveActivityChanged))
      }
    }
    .cancellable(id: CancelID.liveActivityChanges, cancelInFlight: true)
  }

  private func syncLiveActivities(_ state: State) -> Effect<Action> {
    guard state.liveActivityReady, state.isForeground else { return .none }
    let now = state.liveActivityNow
    let festivals = Dictionary(state.festivals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let updates: [Effect<Action>] = state.liveActivities.values.compactMap { activity in
      guard let festival = festivals[activity.festivalID],
            let schedule = FestivalLiveActivitySchedule.resolve(
              festival: festival, pack: state.pack(for: festival.id), now: now
            ) else { return nil }
      if schedule.phase == .finished {
        return .run { send in
          await liveActivityClient.finish(activity.id, schedule.startDate)
          await send(.inner(.liveActivityStopped(activity.festivalID, activity.id)))
        }
        .cancellable(id: LiveActivitySyncID(id: activity.id), cancelInFlight: true)
      }
      guard schedule.phase != activity.phase || schedule.startDate != activity.startDate
        || schedule.endDate != activity.endDate else { return nil }
      return .run { send in
        await liveActivityClient.update(
          activity.id, schedule.phase, schedule.startDate, schedule.endDate
        )
        await send(.inner(.liveActivityUpdated(.init(
          id: activity.id, festivalID: activity.festivalID, phase: schedule.phase,
          startDate: schedule.startDate, endDate: schedule.endDate
        ))))
      }
      .cancellable(id: LiveActivitySyncID(id: activity.id), cancelInFlight: true)
    }
    return .merge(updates + [liveActivityBoundary(state)])
  }

  private func liveActivityBoundary(_ state: State) -> Effect<Action> {
    guard state.liveActivityReady, state.isForeground else {
      return .cancel(id: CancelID.liveActivityBoundary)
    }
    let relevantIDs = Set(state.liveActivities.keys).union(state.selectedFestivalID.map { [$0] } ?? [])
    let next = state.festivals
      .filter { relevantIDs.contains($0.id) }
      .compactMap { festival in
        FestivalLiveActivitySchedule.resolve(
          festival: festival, pack: state.pack(for: festival.id), now: state.liveActivityNow
        )?.nextBoundary
      }
      .min()
    guard let next else { return .cancel(id: CancelID.liveActivityBoundary) }
    let delay = max(1, Int64(next.timeIntervalSince(state.liveActivityNow) * 1000))
    return .run { send in
      try await clock.sleep(for: .milliseconds(delay))
      await send(.inner(.liveActivityBoundary))
    }
    .cancellable(id: CancelID.liveActivityBoundary, cancelInFlight: true)
  }

  private func prefetchImages(_ state: State) -> Effect<Action> {
    guard state.isForeground else {
      return .run { _ in await imagePrefetchClient.stop() }
        .cancellable(id: CancelID.imagePrefetch, cancelInFlight: true)
    }
    let packURLs = state.selectedPack.map { pack in
      [pack.thumbUrl].compactMap(state.imageURL(for:))
        + (pack.artists ?? []).compactMap { state.imageURL(for: $0.imageUrl) }
        + pack.performances.compactMap { state.imageURL(for: $0.imageUrl) }
    } ?? []
    let festivalURLs = state.festivals.compactMap { state.imageURL(for: $0.thumbnailURL?.absoluteString) }
    var seen = Set<URL>()
    let urls = Array((packURLs + festivalURLs).filter { seen.insert($0).inserted }.prefix(100))
    return .run { _ in await imagePrefetchClient.start(urls) }
      .cancellable(id: CancelID.imagePrefetch, cancelInFlight: true)
  }

  private func retryImagesAfterRecovery(in state: inout State) {
    guard state.imageRetryPending else { return }
    state.imageRetryPending = false
    state.imageRevision += 1
  }

  private func identifiedCatalog(_ items: [FestivalCatalogItem]) -> IdentifiedArrayOf<FestivalCatalogItem> {
    var catalog: IdentifiedArrayOf<FestivalCatalogItem> = []
    for item in items where catalog[id: item.id] == nil {
      catalog.append(item)
    }
    return catalog
  }

  private func resolveImageURLs(in state: inout State) {
    var urls: [String: URL] = [:]
    let festivalURLs = state.festivals.compactMap { $0.thumbnailURL?.absoluteString }
    let packURLs = state.selectedPack.map { pack in
      [pack.thumbUrl].compactMap { $0 }
        + (pack.artists ?? []).compactMap(\.imageUrl)
        + pack.performances.compactMap(\.imageUrl)
    } ?? []
    for value in festivalURLs + packURLs where urls[value] == nil {
      urls[value] = catalogService.imageURL(for: value)
    }
    state.imageURLs = urls
  }

  private func watchSelectedPack(_ state: State) -> Effect<Action> {
    guard state.isForeground,
          let id = state.selectedFestivalID,
          (state.selectedFestival?.packVersion ?? 0) > 0 || state.cachedPacks[id] != nil else {
      return .cancel(id: CancelID.packUpdates)
    }
    return .run { send in
      do {
        for try await result in packService.updates(for: id) {
          await send(.inner(.packReceived(id, result)))
        }
      } catch {
        await send(.inner(.packFailed(id)))
      }
    }
    .cancellable(id: CancelID.packUpdates, cancelInFlight: true)
  }

  private func showCachedPack(in state: inout State) {
    if let id = state.selectedFestivalID, let pack = state.cachedPacks[id] {
      state.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      state.connection = .cached
    } else {
      state.selectedPack = nil
      state.connection = state.selectedFestival?.packVersion == 0 ? .unavailable : .connecting
    }
  }
}
