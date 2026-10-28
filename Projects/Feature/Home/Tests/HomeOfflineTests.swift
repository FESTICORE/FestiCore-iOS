import ComposableArchitecture
import FestiCoreFestivalCatalogInterface
import FestiCorePackInterface
import Foundation
import Testing
@testable import Home

struct HomeOfflineTests {
  @Test @MainActor func cachedPackAppearsBeforeFailedRefresh() async {
    let pack = CachedFestivalPack(
      festivalID: "fst_cached", packVersion: 1, etag: "\"v1\"",
      pack: Data(#"{"id":"fst_cached","name":"오프라인 축제","packVersion":1}"#.utf8)
    )
    let store = TestStore(initialState: HomeFeature.State()) {
      HomeFeature()
    } withDependencies: {
      $0.festivalCatalogService = OfflineCatalog()
      $0.packSyncService = CachedPackService(pack: pack)
      $0.festivalSelectionStore = .init(load: { "fst_cached" }, save: { _ in })
    }

    await store.send(.onAppear) { $0.hasStarted = true }
    await store.receive(\.cachedLoaded) {
      $0.cachedPacks = [pack.festivalID: pack]
      $0.selectedFestivalID = pack.festivalID
      $0.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      $0.connection = .cached
    }
    await store.receive(\.catalogFailed) { $0.connection = .offline }
    #expect(store.state.selectedPack?.name == "오프라인 축제")
  }

  @Test @MainActor func cacheReadFailureIsVisibleInState() async {
    let store = TestStore(initialState: HomeFeature.State()) {
      HomeFeature()
    } withDependencies: {
      $0.festivalCatalogService = BrokenCatalog()
      $0.packSyncService = BrokenPackService()
      $0.festivalSelectionStore = .init(load: { nil }, save: { _ in })
    }

    await store.send(.onAppear) { $0.hasStarted = true }
    await store.receive(\.cachedLoaded) {
      $0.catalogCacheReadFailed = true
      $0.packCacheReadFailed = true
      $0.connection = .connecting
    }
    await store.receive(\.catalogFailed) { $0.connection = .offline }
    #expect(store.state.cacheReadFailed)
    #expect(store.state.festivals.isEmpty)
  }

  @Test @MainActor func backgroundCacheLoadDoesNotOpenSocket() async {
    let pack = CachedFestivalPack(
      festivalID: "fst_cached", packVersion: 1, etag: "\"v1\"",
      pack: Data(#"{"id":"fst_cached","name":"오프라인 축제","packVersion":1}"#.utf8)
    )
    let store = TestStore(initialState: HomeFeature.State()) {
      HomeFeature()
    } withDependencies: {
      $0.festivalCatalogService = OfflineCatalog()
      $0.packSyncService = NoSocketPackService()
      $0.festivalSelectionStore = .init(load: { "fst_cached" }, save: { _ in })
    }

    await store.send(.foregroundChanged(false)) { $0.isForeground = false }
    await store.send(.cachedLoaded([], [pack], "fst_cached", false, false)) {
      $0.cachedPacks = [pack.festivalID: pack]
      $0.selectedFestivalID = pack.festivalID
      $0.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      $0.connection = .cached
    }
    await store.receive(\.catalogFailed) { $0.connection = .offline }
  }

  @Test @MainActor func successfulRefreshClearsCacheReadError() async {
    var initialState = HomeFeature.State()
    initialState.catalogCacheReadFailed = true
    initialState.connection = .offline
    let item = FestivalCatalogItem(
      id: "fst_discovered", name: "온라인 축제", packVersion: 0, status: "discovered"
    )
    let store = TestStore(initialState: initialState) { HomeFeature() }

    await store.send(.catalogRefreshed([item])) {
      $0.catalog = [item]
      $0.catalogCacheReadFailed = false
      $0.selectedFestivalID = item.id
      $0.connection = .unavailable
    }
    #expect(!store.state.cacheReadFailed)
  }

  @Test @MainActor func catalogRefreshDoesNotHidePackCacheFailure() async {
    var initialState = HomeFeature.State()
    initialState.packCacheReadFailed = true
    initialState.connection = .offline
    let item = FestivalCatalogItem(
      id: "fst_discovered", name: "온라인 축제", packVersion: 0, status: "discovered"
    )
    let store = TestStore(initialState: initialState) { HomeFeature() }

    await store.send(.catalogRefreshed([item])) {
      $0.catalog = [item]
      $0.selectedFestivalID = item.id
      $0.connection = .unavailable
    }
    #expect(store.state.packCacheReadFailed)
    #expect(store.state.cacheReadFailed)
  }

  @Test func cachedPackRemainsVisibleWithoutCatalog() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_cached",
      packVersion: 2,
      etag: "\"v2\"",
      pack: Data(#"{"id":"fst_cached","name":"저장된 축제","venue":"공원","packVersion":2,"artists":[{"name":"가수"}],"timetable":[{"id":"set_1","artist":"가수","startsAt":"2026-10-29T12:00:00+09:00"}]}"#.utf8)
    )
    var state = HomeFeature.State()
    state.cachedPacks[pack.festivalID] = pack

    #expect(state.festivals.map(\.name) == ["저장된 축제"])
    #expect(state.festivals.first?.isCached == true)
    #expect(try JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack).performances.count == 1)
  }

  @Test func setsAndStagesProvideTimetableWithoutDerivedField() throws {
    let data = Data(#"{"id":"fst_one","stages":[{"id":"main","name":"메인"}],"sets":[{"id":"set_one","stageId":"main","artist":"가수","startsAt":"2026-10-29T12:00:00+09:00","imageUrl":"/api/v1/festivals/images/00000000-0000-0000-0000-000000000000.webp"}]}"#.utf8)
    let document = try JSONDecoder().decode(FestivalPackDocument.self, from: data)

    #expect(document.performances.count == 1)
    #expect(document.performances.first?.stageName == "메인")
    #expect(document.performances.first?.artist == "가수")
  }

  @Test func savedSelectionSurvivesStoreRecreation() throws {
    let suite = "FestiCore.HomeOfflineTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "selectedFestivalID"
    let first = FestivalSelectionStore(
      load: { UserDefaults(suiteName: suite)?.string(forKey: key) },
      save: { UserDefaults(suiteName: suite)?.set($0, forKey: key) }
    )
    first.save("fst_selected")
    let restored = FestivalSelectionStore(
      load: { UserDefaults(suiteName: suite)?.string(forKey: key) },
      save: { UserDefaults(suiteName: suite)?.set($0, forKey: key) }
    )

    #expect(restored.load() == "fst_selected")
  }

  @Test func catalogAndCachedPackUseOneFestivalRow() {
    let item = FestivalCatalogItem(id: "fst_one", name: "최신 이름", packVersion: 3)
    let pack = CachedFestivalPack(
      festivalID: "fst_one", packVersion: 2, etag: "\"v2\"",
      pack: Data(#"{"id":"fst_one","name":"이전 이름","packVersion":2}"#.utf8)
    )
    var state = HomeFeature.State()
    state.catalog = [item]
    state.cachedPacks[pack.festivalID] = pack

    #expect(state.festivals.count == 1)
    #expect(state.festivals.first?.name == "최신 이름")
    #expect(state.festivals.first?.isCached == true)
  }
}

private struct OfflineCatalog: FestivalCatalogService {
  struct NetworkUnavailable: Error {}

  func cachedFestivals() async throws -> [FestivalCatalogItem] { [] }
  func refresh() async throws -> [FestivalCatalogItem] { throw NetworkUnavailable() }
  func imageURL(for _: String?) -> URL? { nil }
}

private struct CachedPackService: PackSyncService {
  let pack: CachedFestivalPack

  func cachedPack(for _: String) async throws -> CachedFestivalPack? { pack }
  func cachedPacks() async throws -> [CachedFestivalPack] { [pack] }
  func sync(for _: String) async throws -> PackSyncResult { .notModified(pack) }
  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}

private struct BrokenCatalog: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { throw OfflineCatalog.NetworkUnavailable() }
  func refresh() async throws -> [FestivalCatalogItem] { throw OfflineCatalog.NetworkUnavailable() }
  func imageURL(for _: String?) -> URL? { nil }
}

private struct BrokenPackService: PackSyncService {
  func cachedPack(for _: String) async throws -> CachedFestivalPack? { nil }
  func cachedPacks() async throws -> [CachedFestivalPack] { throw OfflineCatalog.NetworkUnavailable() }
  func sync(for _: String) async throws -> PackSyncResult { throw OfflineCatalog.NetworkUnavailable() }
  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}

private struct NoSocketPackService: PackSyncService {
  func cachedPack(for _: String) async throws -> CachedFestivalPack? { nil }
  func cachedPacks() async throws -> [CachedFestivalPack] { [] }
  func sync(for _: String) async throws -> PackSyncResult { throw OfflineCatalog.NetworkUnavailable() }
  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    fatalError("Background cache load must not open a WebSocket")
  }
}
