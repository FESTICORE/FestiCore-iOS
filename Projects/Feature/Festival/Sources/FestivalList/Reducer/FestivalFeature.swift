import ComposableArchitecture
import FestivalDomainInterface
import FestiCorePackInterface
import FestivalInterface
import Foundation

@Reducer
public struct FestivalFeature {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalSelectionStore) private var selectionStore
  @Dependency(\.festivalBookedStore) private var bookedStore
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.festivalLiveBoardService) private var liveBoardService
  @Dependency(\.festivalScheduleService) private var scheduleService
  @Dependency(\.festivalImagePrefetchClient) private var imagePrefetchClient
  @Dependency(\.festivalLiveActivityClient) private var liveActivityClient
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
    public var bookedUserID: String?
    public var selectedPack: FestivalPackDocument?
    public var liveBoard: FestivalLiveBoardSnapshot?
    public var liveBoardUnavailable = false
    /// 현재 serverAt을 처음 받은 기기 시각. 304 응답에서도 서버 시각 보정 기준을 유지한다.
    public var liveBoardClockAnchorAt: Date?
    /// 마지막으로 라이브 보드가 정상 확인된 기기 시각. 304 응답도 포함한다.
    public var liveBoardReceivedAt: Date?
    public var isLiveBoardVisible = false
    /// 인증 세션이 있는지. 사용자 ID를 확인하지 못한 세션도 true다.
    public var hasSession = false
    /// 확인된 사용자 ID. 크루의 `나` 표시에만 쓴다.
    public var sessionUserID: String?
    /// 세션이 바뀔 때마다 올려 이전 세션의 응답을 버린다.
    public var accountGeneration = 0
    public var mySchedule: MySchedule?
    public var myScheduleUnavailable = false
    var myScheduleRequestID = 0
    public var connection: Connection = .loading
    public var hasStarted = false
    public var isForeground = true
    public var catalogCacheReadFailed = false
    public var packCacheReadFailed = false
    var liveActivities: [String: FestivalLiveActivityRecord] = [:]
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

    /// 로그아웃·인증 상실 때 이전 계정의 라이브 보드와 예약 목록을 비운다.
    public mutating func clearAccountData() {
      liveBoard = nil
      liveBoardUnavailable = false
      liveBoardClockAnchorAt = nil
      liveBoardReceivedAt = nil
      mySchedule = nil
      myScheduleUnavailable = false
      bookedUserID = nil
      bookedFestivalIDs = []
    }
  }

  /// 서버에 저장된 내 일정 중 한 축제의 공연 ID.
  public struct MySchedule: Equatable {
    public let festivalID: String
    public let setIDs: Set<String>
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
    case delegate(FestivalDelegate)
    case reloadBookmarks(userID: String?)
    case accountChanged
    case sessionChanged(hasSession: Bool, userID: String?)
    case myScheduleSaved(festivalID: String, setIDs: Set<String>)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case foregroundChanged(Bool)
    case refreshRequested
    case selectFestival(String)
    case backToFestivalList
    case toggleBookedFestival(String)
    case liveActivityOnAppear
    case liveBoardOnAppear
    case liveBoardOnDisappear
    case retryMySchedule
    case liveActivityTapped
    case loginTapped
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case cachedLoaded([FestivalCatalogItem], [CachedFestivalPack], String?, Bool, Bool)
    case catalogRefreshed([FestivalCatalogItem])
    case catalogFailed
    case packReceived(String, PackSyncResult)
    case packFailed(String)
    case liveActivitiesLoaded([FestivalLiveActivityRecord], Int)
    case liveActivityStarted(FestivalLiveActivityRecord)
    case liveActivityUpdated(FestivalLiveActivityRecord)
    case liveActivityStopped(String, String)
    case liveActivityFailed(String)
    case liveActivityBoundary
    case liveActivityChanged
    case liveBoardLoaded(String, generation: Int, FestivalLiveBoardSnapshot)
    case liveBoardFailed(String, generation: Int)
    case myScheduleLoaded(festivalID: String, requestID: Int, generation: Int, Set<String>)
    case myScheduleFailed(festivalID: String, requestID: Int, generation: Int)
  }

  private enum CancelID {
    case packUpdates, imagePrefetch, liveActivityChanges, liveActivityBoundary, liveBoard, mySchedule
  }
  private struct LiveActivitySyncID: Hashable { let id: String }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        state.bookedFestivalIDs = state.bookedUserID.map { bookedStore.load(for: $0) } ?? []
        guard !state.hasStarted else { return .none }
        state.hasStarted = true
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

      case .view(.liveBoardOnAppear):
        state.isLiveBoardVisible = true
        return .merge(watchLiveBoard(state), loadMySchedule(&state))

      case .view(.liveBoardOnDisappear):
        state.isLiveBoardVisible = false
        state.mySchedule = nil
        state.myScheduleUnavailable = false
        state.myScheduleRequestID += 1
        return .merge(.cancel(id: CancelID.liveBoard), .cancel(id: CancelID.mySchedule))

      case .view(.retryMySchedule):
        return loadMySchedule(&state)

      case .view(.loginTapped):
        return .send(.delegate(.loginRequested))

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
        state.catalog = FestivalCatalogUseCase.unique(catalog)
        state.cachedPacks = Dictionary(uniqueKeysWithValues: packs.map { ($0.festivalID, $0) })
        if !state.festivals.isEmpty { state.viewState = .loaded }
        state.catalogCacheReadFailed = catalogReadFailed
        state.packCacheReadFailed = packReadFailed
        state.selectedFestivalID = FestivalCatalogUseCase.initialSelection(
          from: state.festivals,
          currentID: state.selectedFestivalID,
          savedID: savedID
        )
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        return .merge(refreshCatalog(), watchSelectedPack(state), prefetchImages(state), syncLiveActivities(state))

      case .view(.refreshRequested):
        state.packWatchFailed = false
        return .merge(refreshCatalog(), watchSelectedPack(state))

      case let .view(.foregroundChanged(isForeground)):
        state.isForeground = isForeground
        if isForeground {
          state.bookedFestivalIDs = state.bookedUserID.map { bookedStore.load(for: $0) } ?? []
        }
        guard state.hasStarted else {
          return isForeground ? .send(.view(.onAppear)) : prefetchImages(state)
        }
        if isForeground {
          state.packWatchFailed = false
          if state.liveActivityReady { state.liveActivityNow = date.now }
          return .merge(
            refreshCatalog(), watchSelectedPack(state), prefetchImages(state),
            state.liveActivityReady ? loadLiveActivities(revision: state.liveActivityRevision) : .none,
            state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
            loadMySchedule(&state)
          )
        }
        return .merge(
          .cancel(id: CancelID.packUpdates),
          .cancel(id: CancelID.liveBoard),
          .cancel(id: CancelID.liveActivityBoundary),
          prefetchImages(state)
        )

      case let .view(.selectFestival(id)):
        guard state.festivals.contains(where: { $0.id == id }) else { return .none }
        state.selectedFestivalID = id
        state.liveBoard = nil
        state.liveBoardUnavailable = false
        state.liveBoardClockAnchorAt = nil
        state.liveBoardReceivedAt = nil
        state.mySchedule = nil
        state.myScheduleUnavailable = false
        state.liveActivityError = nil
        if state.liveActivityReady { state.liveActivityNow = date.now }
        state.packWatchFailed = false
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        return .merge(
          .run { _ in selectionStore.save(id) },
          watchSelectedPack(state),
          state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
          loadMySchedule(&state),
          prefetchImages(state),
          liveActivityBoundary(state)
        )

      case .view(.backToFestivalList):
        return .none

      case let .inner(.liveBoardLoaded(id, generation, snapshot)):
        guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
        if state.liveBoard?.serverAt != snapshot.serverAt || state.liveBoardClockAnchorAt == nil {
          state.liveBoardClockAnchorAt = date.now
        }
        state.liveBoard = snapshot
        state.liveBoardUnavailable = false
        state.liveBoardReceivedAt = date.now
        return .none

      case let .inner(.liveBoardFailed(id, generation)):
        guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
        state.liveBoardUnavailable = true
        return .none

      case let .inner(.myScheduleLoaded(festivalID, requestID, generation, setIDs)):
        guard state.selectedFestivalID == festivalID,
              state.myScheduleRequestID == requestID,
              state.accountGeneration == generation,
              state.isLiveBoardVisible, state.hasSession else { return .none }
        state.mySchedule = MySchedule(festivalID: festivalID, setIDs: setIDs)
        state.myScheduleUnavailable = false
        return .none

      case let .inner(.myScheduleFailed(festivalID, requestID, generation)):
        guard state.selectedFestivalID == festivalID,
              state.myScheduleRequestID == requestID,
              state.accountGeneration == generation,
              state.isLiveBoardVisible, state.hasSession else { return .none }
        state.mySchedule = nil
        state.myScheduleUnavailable = true
        return .none


      case let .view(.toggleBookedFestival(id)):
        guard state.festivals.contains(where: { $0.id == id }) else { return .none }
        return .send(.delegate(.bookmarkRequested(id)))

      case let .reloadBookmarks(userID):
        state.bookedUserID = userID
        state.bookedFestivalIDs = userID.map { bookedStore.load(for: $0) } ?? []
        return .none

      case .accountChanged:
        // 같은 로그아웃 전환의 `sessionChanged`가 먼저 처리됐다면 라이브 보드는 이미 비우고 다시 불렀다.
        guard state.hasSession || state.sessionUserID != nil else {
          state.bookedUserID = nil
          state.bookedFestivalIDs = []
          return .none
        }
        state.clearAccountData()
        state.hasSession = false
        state.sessionUserID = nil
        state.accountGeneration += 1
        return .merge(
          state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
          .cancel(id: CancelID.mySchedule)
        )

      case let .sessionChanged(hasSession, userID):
        guard state.hasSession != hasSession || state.sessionUserID != userID else { return .none }
        if let bookedUserID = state.bookedUserID, bookedUserID != userID {
          state.bookedUserID = nil
          state.bookedFestivalIDs = []
        }
        state.hasSession = hasSession
        state.sessionUserID = userID
        state.accountGeneration += 1
        state.liveBoard = nil
        state.liveBoardUnavailable = false
        state.liveBoardClockAnchorAt = nil
        state.liveBoardReceivedAt = nil
        state.mySchedule = nil
        state.myScheduleUnavailable = false
        return .merge(
          state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
          loadMySchedule(&state)
        )

      case let .myScheduleSaved(festivalID, setIDs):
        guard state.selectedFestivalID == festivalID,
              state.hasSession, state.isLiveBoardVisible else { return .none }
        state.myScheduleRequestID += 1
        state.mySchedule = MySchedule(festivalID: festivalID, setIDs: setIDs)
        state.myScheduleUnavailable = false
        return .cancel(id: CancelID.mySchedule)

      case .delegate:
        return .none

      case let .inner(.catalogRefreshed(catalog)):
        state.viewState = .loaded
        if state.liveActivityReady { state.liveActivityNow = date.now }
        let previouslyAvailable = (state.selectedFestival?.packVersion ?? 0) > 0
        let restartFailedWatch = state.packWatchFailed
        state.packWatchFailed = false
        state.catalog = FestivalCatalogUseCase.unique(catalog)
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
        var current: [String: FestivalLiveActivityRecord] = [:]
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
    let urls = FestivalImageUseCase.prefetchURLs(
      festivals: state.festivals,
      selectedPack: state.selectedPack,
      resolvedURL: state.imageURL(for:)
    )
    return .run { _ in await imagePrefetchClient.start(urls) }
      .cancellable(id: CancelID.imagePrefetch, cancelInFlight: true)
  }

  private func retryImagesAfterRecovery(in state: inout State) {
    guard state.imageRetryPending else { return }
    state.imageRetryPending = false
    state.imageRevision += 1
  }

  private func resolveImageURLs(in state: inout State) {
    var urls: [String: URL] = [:]
    for value in FestivalImageUseCase.sourceValues(
      festivals: state.festivals,
      selectedPack: state.selectedPack
    ) {
      urls[value] = catalogService.imageURL(for: value)
    }
    state.imageURLs = urls
  }

  private func watchLiveBoard(_ state: State) -> Effect<Action> {
    guard state.isForeground, state.isLiveBoardVisible,
          let id = state.selectedFestivalID else {
      return .cancel(id: CancelID.liveBoard)
    }
    let generation = state.accountGeneration
    return .run { send in
      while !Task.isCancelled {
        var interval: TimeInterval = 35
        do {
          let snapshot = try await liveBoardService.refresh(for: id)
          await send(.inner(.liveBoardLoaded(id, generation: generation, snapshot)))
        } catch FestivalLiveBoardError.rateLimited(let retryAfter) {
          interval = max(interval, retryAfter)
          await send(.inner(.liveBoardFailed(id, generation: generation)))
        } catch {
          await send(.inner(.liveBoardFailed(id, generation: generation)))
        }
        try await clock.sleep(for: .seconds(interval))
      }
    }
    .cancellable(id: CancelID.liveBoard, cancelInFlight: true)
  }

  /// 세션이 있고 라이브 보드가 보일 때 내 일정을 불러온다.
  private func loadMySchedule(_ state: inout State) -> Effect<Action> {
    guard state.hasSession, state.isLiveBoardVisible, let id = state.selectedFestivalID else {
      return .cancel(id: CancelID.mySchedule)
    }
    state.myScheduleRequestID += 1
    state.myScheduleUnavailable = false
    let requestID = state.myScheduleRequestID
    let generation = state.accountGeneration
    return .run { send in
      do {
        let setIDs = try await scheduleService.fetch(festivalID: id).setIDs
        await send(.inner(.myScheduleLoaded(
          festivalID: id, requestID: requestID, generation: generation, Set(setIDs)
        )))
      } catch {
        await send(.inner(.myScheduleFailed(
          festivalID: id, requestID: requestID, generation: generation
        )))
      }
    }
    .cancellable(id: CancelID.mySchedule, cancelInFlight: true)
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
