import ComposableArchitecture
import FestiCoreFestivalDomainInterface
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

    await store.send(.view(.onAppear)) { $0.hasStarted = true }
    await store.receive(\.inner.cachedLoaded) {
      $0.cachedPacks = [pack.festivalID: pack]
      $0.selectedFestivalID = pack.festivalID
      $0.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      $0.connection = .cached
    }
    await store.receive(\.inner.catalogFailed) { $0.connection = .offline }
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

    await store.send(.view(.onAppear)) { $0.hasStarted = true }
    await store.receive(\.inner.cachedLoaded) {
      $0.catalogCacheReadFailed = true
      $0.packCacheReadFailed = true
      $0.connection = .connecting
    }
    await store.receive(\.inner.catalogFailed) { $0.connection = .offline }
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

    await store.send(.view(.foregroundChanged(false))) { $0.isForeground = false }
    await store.send(.inner(.cachedLoaded([], [pack], "fst_cached", false, false))) {
      $0.cachedPacks = [pack.festivalID: pack]
      $0.selectedFestivalID = pack.festivalID
      $0.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      $0.connection = .cached
    }
    await store.receive(\.inner.catalogFailed) { $0.connection = .offline }
  }

  @Test @MainActor func successfulRefreshClearsCacheReadError() async {
    var initialState = HomeFeature.State()
    initialState.catalogCacheReadFailed = true
    initialState.connection = .offline
    let item = FestivalCatalogItem(
      id: "fst_discovered", name: "온라인 축제", packVersion: 0, status: "discovered"
    )
    let store = TestStore(initialState: initialState) { HomeFeature() }

    await store.send(.inner(.catalogRefreshed([item]))) {
      $0.catalog = [item]
      $0.imageRevision = 1
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

    await store.send(.inner(.catalogRefreshed([item]))) {
      $0.catalog = [item]
      $0.imageRevision = 1
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

  @Test @MainActor func duplicateCatalogIDsKeepFirstItem() async {
    let first = FestivalCatalogItem(id: "fst_one", name: "첫 번째", packVersion: 0)
    let duplicate = FestivalCatalogItem(id: "fst_one", name: "두 번째", packVersion: 0)
    let other = FestivalCatalogItem(id: "fst_two", name: "다른 축제", packVersion: 0)
    let store = TestStore(initialState: HomeFeature.State()) { HomeFeature() }

    await store.send(.inner(.catalogRefreshed([first, duplicate, other]))) {
      $0.catalog = [first, other]
      $0.imageRevision = 1
      $0.selectedFestivalID = first.id
      $0.connection = .unavailable
    }
    await store.finish()
    #expect(store.state.catalog.ids == ["fst_one", "fst_two"])
    #expect(store.state.festivals.map(\.name) == ["첫 번째", "다른 축제"])
  }

  @Test @MainActor func catalogRecoveryRetriesImagesWithoutPack() async {
    let item = FestivalCatalogItem(
      id: "fst_discovered", name: "발견된 축제",
      thumbnailURL: URL(string: "https://example.com/poster.webp"),
      packVersion: 0
    )
    var initialState = HomeFeature.State()
    initialState.catalog = [item]
    initialState.selectedFestivalID = item.id
    initialState.connection = .offline
    let store = TestStore(initialState: initialState) { HomeFeature() } withDependencies: {
      $0.festivalCatalogService = ImageCatalog()
    }

    await store.send(.inner(.catalogRefreshed([item]))) {
      $0.imageRevision = 1
      $0.imageURLs = [item.thumbnailURL!.absoluteString: item.thumbnailURL!]
      $0.connection = .unavailable
    }
    await store.send(.inner(.catalogRefreshed([item]))) { $0.imageRevision = 2 }
  }

  @Test @MainActor func receivedPackPrefetchesImagesAndBackgroundStops() async throws {
    let recorder = PrefetchRecorder()
    let pack = CachedFestivalPack(
      festivalID: "fst_images", packVersion: 1, etag: "\"v1\"",
      pack: Data(#"{"id":"fst_images","name":"이미지 축제","thumbUrl":"https://example.com/poster.webp","artists":[{"name":"가수","imageUrl":"https://example.com/artist.webp"}],"timetable":[{"id":"set_1","imageUrl":"https://example.com/artist.webp"}]}"#.utf8)
    )
    var initialState = HomeFeature.State()
    initialState.selectedFestivalID = pack.festivalID
    let store = TestStore(initialState: initialState) { HomeFeature() } withDependencies: {
      $0.festivalCatalogService = ImageCatalog()
      $0.homeImagePrefetchClient = HomeImagePrefetchClient(
        start: { urls in await recorder.start(urls) },
        stop: { await recorder.stop() }
      )
    }

    await store.send(.inner(.packReceived(pack.festivalID, .updated(pack)))) {
      $0.cachedPacks[pack.festivalID] = pack
      $0.imageURLs = [
        "https://example.com/poster.webp": URL(string: "https://example.com/poster.webp")!,
        "https://example.com/artist.webp": URL(string: "https://example.com/artist.webp")!
      ]
      $0.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      $0.connection = .live
      $0.imageRevision = 1
    }
    await store.finish()
    #expect(await recorder.startedURLs() == [
      URL(string: "https://example.com/poster.webp")!,
      URL(string: "https://example.com/artist.webp")!
    ])

    await store.send(.view(.foregroundChanged(false))) { $0.isForeground = false }
    await store.finish()
    #expect(await recorder.stopCount() == 1)
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

private struct ImageCatalog: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { [] }
  func refresh() async throws -> [FestivalCatalogItem] { [] }
  func imageURL(for value: String?) -> URL? { value.flatMap(URL.init(string:)) }
}

private actor PrefetchRecorder {
  private var urls: [URL] = []
  private var stops = 0

  func start(_ urls: [URL]) { self.urls = urls }
  func stop() { stops += 1 }
  func startedURLs() -> [URL] { urls }
  func stopCount() -> Int { stops }
}
