import ComposableArchitecture
import FestiCoreFestivalCatalogInterface
import FestiCorePackInterface
import Foundation

@Reducer
public struct HomeFeature {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalSelectionStore) private var selectionStore
  @Dependency(\.packSyncService) private var packService

  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var catalog: [FestivalCatalogItem] = []
    public var cachedPacks: [String: CachedFestivalPack] = [:]
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
  }

  public enum Connection: Equatable {
    case loading
    case cached
    case connecting
    case live
    case offline
    case unavailable
  }

  @CasePathable
  public enum Action: Equatable {
    case onAppear
    case foregroundChanged(Bool)
    case refreshRequested
    case selectFestival(String)
    case cachedLoaded([FestivalCatalogItem], [CachedFestivalPack], String?, Bool, Bool)
    case catalogRefreshed([FestivalCatalogItem])
    case catalogFailed
    case packReceived(String, PackSyncResult)
    case packFailed(String)
  }

  private enum CancelID { case packUpdates }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        guard !state.hasStarted else { return .none }
        state.hasStarted = true
        return .run { send in
          async let catalog = try? catalogService.cachedFestivals()
          async let packs = try? packService.cachedPacks()
          let cachedCatalog = await catalog
          let cachedPacks = await packs
          await send(.cachedLoaded(
            cachedCatalog ?? [], cachedPacks ?? [], selectionStore.load(),
            cachedCatalog == nil, cachedPacks == nil
          ))
        }

      case let .cachedLoaded(catalog, packs, savedID, catalogReadFailed, packReadFailed):
        state.catalog = catalog
        state.cachedPacks = Dictionary(uniqueKeysWithValues: packs.map { ($0.festivalID, $0) })
        state.catalogCacheReadFailed = catalogReadFailed
        state.packCacheReadFailed = packReadFailed
        let available = state.festivals
        state.selectedFestivalID = available.first { $0.id == savedID }?.id
          ?? available.first { $0.isCached }?.id
          ?? available.first { $0.packVersion > 0 }?.id
          ?? available.first?.id
        showCachedPack(in: &state)
        return .merge(refreshCatalog(), watchSelectedPack(state))

      case .refreshRequested:
        return .merge(refreshCatalog(), watchSelectedPack(state))

      case let .foregroundChanged(isForeground):
        state.isForeground = isForeground
        guard state.hasStarted else {
          return isForeground ? .send(.onAppear) : .none
        }
        if isForeground {
          return .merge(refreshCatalog(), watchSelectedPack(state))
        }
        return .cancel(id: CancelID.packUpdates)

      case let .selectFestival(id):
        guard state.festivals.contains(where: { $0.id == id }) else { return .none }
        state.selectedFestivalID = id
        showCachedPack(in: &state)
        return .merge(
          .run { _ in selectionStore.save(id) },
          watchSelectedPack(state)
        )

      case let .catalogRefreshed(catalog):
        let previouslyAvailable = (state.selectedFestival?.packVersion ?? 0) > 0
        state.catalog = catalog
        state.catalogCacheReadFailed = false
        if state.selectedFestival == nil, let first = state.festivals.first(where: { $0.isCached || $0.packVersion > 0 }) ?? state.festivals.first {
          state.selectedFestivalID = first.id
          showCachedPack(in: &state)
          return watchSelectedPack(state)
        }
        if state.selectedPack == nil, state.selectedFestival?.packVersion == 0 {
          state.connection = .unavailable
        }
        return !previouslyAvailable && (state.selectedFestival?.packVersion ?? 0) > 0
          ? watchSelectedPack(state) : .none

      case .catalogFailed:
        if state.connection != .live { state.connection = .offline }
        return .none

      case let .packReceived(id, result):
        guard state.selectedFestivalID == id else { return .none }
        switch result {
        case let .updated(pack), let .notModified(pack):
          state.cachedPacks[id] = pack
          if let document = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack) {
            state.selectedPack = document
            state.connection = .live
            state.packCacheReadFailed = false
          } else {
            state.connection = state.selectedPack == nil ? .unavailable : .cached
          }
        case .retryAfter:
          state.connection = state.selectedPack == nil ? .connecting : .cached
        }
        return .none

      case let .packFailed(id):
        guard state.selectedFestivalID == id else { return .none }
        state.connection = .offline
        return .none
      }
    }
  }

  private func refreshCatalog() -> Effect<Action> {
    .run { send in
      do { await send(.catalogRefreshed(try await catalogService.refresh())) }
      catch { await send(.catalogFailed) }
    }
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
          await send(.packReceived(id, result))
        }
      } catch {
        await send(.packFailed(id))
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
