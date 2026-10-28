import ComposableArchitecture
import FestiCoreFestivalDomainInterface
import FestiCorePackInterface
import Foundation

@Reducer
public struct HomeFeature {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalSelectionStore) private var selectionStore
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.homeImagePrefetchClient) private var imagePrefetchClient

  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var catalog: IdentifiedArrayOf<FestivalCatalogItem> = []
    public var cachedPacks: [String: CachedFestivalPack] = [:]
    public var imageURLs: [String: URL] = [:]
    public var imageRevision = 0
    public var imageRetryPending = false
    public var selectedFestivalID: String?
    public var selectedPack: FestivalPackDocument?
    public var connection: Connection = .loading
    public var hasStarted = false
    public var isForeground = true
    public var catalogCacheReadFailed = false
    public var packCacheReadFailed = false

    public var cacheReadFailed: Bool {
      catalogCacheReadFailed || packCacheReadFailed
    }

    public init() {}

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
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case cachedLoaded([FestivalCatalogItem], [CachedFestivalPack], String?, Bool, Bool)
    case catalogRefreshed([FestivalCatalogItem])
    case catalogFailed
    case packReceived(String, PackSyncResult)
    case packFailed(String)
  }

  private enum CancelID { case packUpdates, imagePrefetch }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
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

      case let .inner(.cachedLoaded(catalog, packs, savedID, catalogReadFailed, packReadFailed)):
        state.catalog = identifiedCatalog(catalog)
        state.cachedPacks = Dictionary(uniqueKeysWithValues: packs.map { ($0.festivalID, $0) })
        state.catalogCacheReadFailed = catalogReadFailed
        state.packCacheReadFailed = packReadFailed
        let available = state.festivals
        state.selectedFestivalID = available.first { $0.id == savedID }?.id
          ?? available.first { $0.isCached }?.id
          ?? available.first { $0.packVersion > 0 }?.id
          ?? available.first?.id
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        return .merge(refreshCatalog(), watchSelectedPack(state), prefetchImages(state))

      case .view(.refreshRequested):
        return .merge(refreshCatalog(), watchSelectedPack(state))

      case let .view(.foregroundChanged(isForeground)):
        state.isForeground = isForeground
        guard state.hasStarted else {
          return isForeground ? .send(.view(.onAppear)) : prefetchImages(state)
        }
        if isForeground {
          return .merge(refreshCatalog(), watchSelectedPack(state), prefetchImages(state))
        }
        return .merge(.cancel(id: CancelID.packUpdates), prefetchImages(state))

      case let .view(.selectFestival(id)):
        guard state.festivals.contains(where: { $0.id == id }) else { return .none }
        state.selectedFestivalID = id
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        return .merge(
          .run { _ in selectionStore.save(id) },
          watchSelectedPack(state),
          prefetchImages(state)
        )

      case let .inner(.catalogRefreshed(catalog)):
        let previouslyAvailable = (state.selectedFestival?.packVersion ?? 0) > 0
        state.catalog = identifiedCatalog(catalog)
        retryImagesAfterRecovery(in: &state)
        state.catalogCacheReadFailed = false
        if state.selectedFestival == nil, let first = state.festivals.first(where: { $0.isCached || $0.packVersion > 0 }) ?? state.festivals.first {
          state.selectedFestivalID = first.id
          showCachedPack(in: &state)
          resolveImageURLs(in: &state)
          return .merge(watchSelectedPack(state), prefetchImages(state))
        }
        resolveImageURLs(in: &state)
        if state.selectedPack == nil, state.selectedFestival?.packVersion == 0 {
          state.connection = .unavailable
        }
        let prefetch = prefetchImages(state)
        return !previouslyAvailable && (state.selectedFestival?.packVersion ?? 0) > 0
          ? .merge(watchSelectedPack(state), prefetch) : prefetch

      case .inner(.catalogFailed):
        state.imageRetryPending = true
        if state.connection != .live { state.connection = .offline }
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
            state.packCacheReadFailed = false
            let retryPending = state.imageRetryPending
            retryImagesAfterRecovery(in: &state)
            resolveImageURLs(in: &state)
            return previousPack != document || retryPending ? prefetchImages(state) : .none
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
        state.connection = .offline
        return .none
      }
    }
  }

  private func refreshCatalog() -> Effect<Action> {
    .run { send in
      do { await send(.inner(.catalogRefreshed(try await catalogService.refresh()))) }
      catch { await send(.inner(.catalogFailed)) }
    }
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
    let catalogURLs = state.catalog.compactMap { state.imageURL(for: $0.thumbnailURL?.absoluteString) }
    var seen = Set<URL>()
    let urls = Array((packURLs + catalogURLs).filter { seen.insert($0).inserted }.prefix(100))
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
    let catalogURLs = state.catalog.compactMap { $0.thumbnailURL?.absoluteString }
    let packURLs = state.selectedPack.map { pack in
      [pack.thumbUrl].compactMap { $0 }
        + (pack.artists ?? []).compactMap(\.imageUrl)
        + pack.performances.compactMap(\.imageUrl)
    } ?? []
    for value in catalogURLs + packURLs where urls[value] == nil {
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
