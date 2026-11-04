import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalPackDownloadFeatureTests {
  @Test @MainActor func deletingUnbookedCachedPackRestoresBookmarkGuidanceWithoutRestartingWebSocket() async throws {
    let watched = LockIsolated(0)
    let oldPack = CachedFestivalPack(
      festivalID: "festival", packVersion: 1, etag: "v1",
      pack: Data(#"{"id":"festival","name":"축제","packVersion":1}"#.utf8)
    )
    var initial = FestivalFeature.State(selectedFestivalID: "festival")
    initial.catalog = [FestivalCatalogItem(id: "festival", name: "축제", firstDate: "2099-11-21", packVersion: 2)]
    initial.cachedPacks = ["festival": oldPack]
    initial.selectedPack = try JSONDecoder().decode(FestivalPackDocument.self, from: oldPack.pack)
    initial.connection = .cached
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.festivalPackUseCase = MockFestivalPackUseCase(
        cachedPacks: { [] },
        packUpdates: { _ in
          watched.withValue { $0 += 1 }
          return AsyncThrowingStream { $0.finish() }
        }
      )
      $0.festivalImageUseCase = MockFestivalImageUseCase(
        imageURL: { _ in nil }, startPrefetch: { _ in }, stopPrefetch: {}
      )
    }

    await store.send(.view(.reloadCachedPacks))
    await store.receive(\.async.reloadCachedPacks)
    await store.receive(\.inner.cachedPacksReloaded) {
      $0.cachedPacks = [:]
      $0.selectedPack = nil
      $0.connection = .unavailable
    }
    await store.finish()
    #expect(watched.value == 0)
    let copy = FestivalListPresentation.packCopy(
      for: try #require(store.state.festivals.first),
      isBooked: store.state.bookedFestivalIDs.contains("festival")
    )
    #expect(copy == .unavailable("예매한 페스티벌로 등록하면 팩을 받을 수 있어요"))
  }

  @Test @MainActor func refreshedCachedPackKeepsWebSocketUpdateWatch() async throws {
    let watched = LockIsolated(0)
    let pack = CachedFestivalPack(
      festivalID: "festival", packVersion: 2, etag: "v2",
      pack: Data(#"{"id":"festival","name":"축제","packVersion":2}"#.utf8)
    )
    var initial = FestivalFeature.State(selectedFestivalID: "festival")
    initial.catalog = [FestivalCatalogItem(id: "festival", name: "축제", firstDate: "2099-11-21", packVersion: 2)]
    initial.bookedFestivalIDs = ["festival"]
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.festivalPackUseCase = MockFestivalPackUseCase(
        cachedPacks: { [pack] },
        packUpdates: { _ in
          watched.withValue { $0 += 1 }
          return AsyncThrowingStream { $0.finish() }
        }
      )
      $0.festivalImageUseCase = MockFestivalImageUseCase(
        imageURL: { _ in nil }, startPrefetch: { _ in }, stopPrefetch: {}
      )
    }

    await store.send(.view(.reloadCachedPacks))
    await store.receive(\.async.reloadCachedPacks)
    await store.receive(\.inner.cachedPacksReloaded) {
      $0.cachedPacks = ["festival": pack]
      $0.selectedPack = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
      $0.connection = .cached
    }
    await store.finish()
    #expect(watched.value == 1)
    let copy = FestivalListPresentation.packCopy(
      for: try #require(store.state.festivals.first),
      isBooked: store.state.bookedFestivalIDs.contains("festival")
    )
    #expect(copy == .received("팩 받음 · 최신 버전"))
  }

  @Test @MainActor func redownloadAfterDeletingSelectedPackResumesWebSocketUpdates() async throws {
    let watched = LockIsolated(0)
    let oldPack = CachedFestivalPack(
      festivalID: "festival",
      packVersion: 1,
      etag: "v1",
      pack: Data(#"{"id":"festival","name":"기존 축제"}"#.utf8)
    )
    let downloadedPack = CachedFestivalPack(
      festivalID: "festival",
      packVersion: 2,
      etag: "v2",
      pack: Data(#"{"id":"festival","name":"다시 받은 축제"}"#.utf8)
    )
    let updatedPack = CachedFestivalPack(
      festivalID: "festival",
      packVersion: 3,
      etag: "v3",
      pack: Data(#"{"id":"festival","name":"실시간 축제"}"#.utf8)
    )
    var initial = FestivalFeature.State(selectedFestivalID: "festival")
    initial.catalog = [FestivalCatalogItem(
      id: "festival",
      name: "축제",
      firstDate: "2099-11-21",
      packVersion: 2
    )]
    initial.cachedPacks = ["festival": oldPack]
    initial.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: oldPack.pack
    )
    initial.connection = .cached
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.date = .constant(Date(timeIntervalSince1970: 1_800_000_000))
      $0.festivalPackUseCase = MockFestivalPackUseCase(
        cachedPacks: { [] },
        packUpdates: { _ in
          watched.withValue { $0 += 1 }
          return AsyncThrowingStream { continuation in
            continuation.yield(.updated(updatedPack))
            continuation.finish()
          }
        },
        downloadPack: { _ in
          AsyncThrowingStream { continuation in
            continuation.yield(.finished(.updated(downloadedPack)))
            continuation.finish()
          }
        }
      )
      $0.festivalImageUseCase = MockFestivalImageUseCase(
        imageURL: { _ in nil },
        startPrefetch: { _ in },
        stopPrefetch: {}
      )
    }

    await store.send(.view(.reloadCachedPacks))
    await store.receive(\.async.reloadCachedPacks)
    await store.receive(\.inner.cachedPacksReloaded) {
      $0.cachedPacks = [:]
      $0.selectedPack = nil
      $0.connection = .unavailable
    }
    await store.send(.view(.downloadPack("festival"))) {
      $0.packDownloads["festival"] = .downloading(nil)
    }
    await store.receive(.async(.downloadPack(
      "festival",
      generation: 0
    )))
    await store.receive(.inner(.packDownloadFinished(
      "festival",
      generation: 0,
      .updated(downloadedPack)
    ))) {
      $0.packDownloads = [:]
      $0.cachedPacks["festival"] = downloadedPack
      $0.selectedPack = try? JSONDecoder().decode(
        FestivalPackDocument.self,
        from: downloadedPack.pack
      )
      $0.connection = .live
    }
    await store.receive(.inner(.packReceived(
      "festival",
      .updated(updatedPack)
    ))) {
      $0.cachedPacks["festival"] = updatedPack
      $0.selectedPack = try? JSONDecoder().decode(
        FestivalPackDocument.self,
        from: updatedPack.pack
      )
    }
    await store.finish()
    #expect(watched.value == 1)
    #expect(store.state.selectedPack?.name == "실시간 축제")
  }

  @Test @MainActor func downloadButtonTracksMeasuredProgressAndCachedResult() async {
    let festival = FestivalCatalogItem(
      id: "festival", name: "축제", firstDate: "2099-11-21", packVersion: 2
    )
    let pack = CachedFestivalPack(
      festivalID: "festival", packVersion: 2, etag: "v2", pack: Data("{}".utf8)
    )
    var initial = FestivalFeature.State()
    initial.catalog = [festival]
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date = .constant(Date(timeIntervalSince1970: 1_800_000_000))
      $0.festivalPackUseCase = MockFestivalPackUseCase(downloadPack: { _ in
        AsyncThrowingStream { continuation in
          continuation.yield(.progress(.init(receivedBytes: 62, totalBytes: 100)))
          continuation.yield(.finished(.updated(pack)))
          continuation.finish()
        }
      })
    }

    await store.send(.view(.downloadPack("festival"))) {
      $0.packDownloads["festival"] = .downloading(nil)
    }
    await store.receive(.async(.downloadPack("festival", generation: 0)))
    await store.receive(.inner(.packDownloadProgress(
      "festival", generation: 0, .init(receivedBytes: 62, totalBytes: 100)
    ))) {
      $0.packDownloads["festival"] = .downloading(.init(receivedBytes: 62, totalBytes: 100))
    }
    await store.receive(.inner(.packDownloadFinished("festival", generation: 0, .updated(pack)))) {
      $0.packDownloads = [:]
      $0.cachedPacks["festival"] = pack
    }
  }

  @Test(
    arguments: ["ended", "openingSoon", "discovered"],
    [false, true]
  )
  @MainActor func publishedPackDownloadsRegardlessOfTimingStatusAndBooking(
    status: String,
    isBooked: Bool
  ) async {
    let pack = CachedFestivalPack(
      festivalID: "festival",
      packVersion: 2,
      etag: "v2",
      pack: Data("{}".utf8)
    )
    var initial = FestivalFeature.State()
    initial.catalog = [FestivalCatalogItem(
      id: "festival",
      name: "축제",
      firstDate: status == "ended" ? "2000-01-01" : "2099-11-21",
      lastDate: status == "ended" ? "2000-01-02" : "2099-11-22",
      packVersion: 2,
      status: status
    )]
    initial.bookedFestivalIDs = isBooked ? ["festival"] : []
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.date = .constant(Date(timeIntervalSince1970: 1_800_000_000))
      $0.festivalPackUseCase = MockFestivalPackUseCase(downloadPack: { id in
        #expect(id == "festival")
        return AsyncThrowingStream { continuation in
          continuation.yield(.finished(.updated(pack)))
          continuation.finish()
        }
      })
    }

    await store.send(.view(.downloadPack("festival"))) {
      $0.packDownloads["festival"] = .downloading(nil)
    }
    await store.receive(.async(.downloadPack(
      "festival",
      generation: 0
    )))
    await store.receive(.inner(.packDownloadFinished(
      "festival",
      generation: 0,
      .updated(pack)
    ))) {
      $0.packDownloads = [:]
      $0.cachedPacks["festival"] = pack
    }
    await store.finish()
    #expect(store.state.bookedFestivalIDs == initial.bookedFestivalIDs)
  }

  @Test(arguments: [2, 3])
  @MainActor func currentOrNewerCachedPackCannotDownload(cachedVersion: Int) async {
    var initial = FestivalFeature.State()
    initial.catalog = [FestivalCatalogItem(
      id: "festival",
      name: "축제",
      firstDate: "2000-01-01",
      packVersion: 2,
      status: "ended"
    )]
    initial.cachedPacks["festival"] = CachedFestivalPack(
      festivalID: "festival",
      packVersion: cachedVersion,
      etag: "cached",
      pack: Data("{}".utf8)
    )
    let store = TestStore(initialState: initial) { FestivalFeature() }

    await store.send(.view(.downloadPack("festival")))
    await store.finish()
    #expect(store.state.packDownloads.isEmpty)
  }

  @Test @MainActor func unpublishedFestivalCannotDownload() async {
    var initial = FestivalFeature.State()
    initial.catalog = [FestivalCatalogItem(
      id: "festival",
      name: "축제",
      firstDate: "2099-11-21",
      packVersion: 0
    )]
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.view(.downloadPack("festival")))
    #expect(store.state.packDownloads.isEmpty)
  }

  @Test @MainActor func updateHintResetsProgressAndStaleAccountEventsAreIgnored() async {
    var initial = FestivalFeature.State()
    initial.accountGeneration = 2
    initial.packDownloads["festival"] = .downloading(.init(receivedBytes: 80, totalBytes: 100))
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.inner(.packDownloadReset("festival", generation: 1)))
    await store.send(.inner(.packDownloadReset("festival", generation: 2))) {
      $0.packDownloads["festival"] = .downloading(nil)
    }
    await store.send(.inner(.packDownloadProgress(
      "festival", generation: 1, .init(receivedBytes: 90, totalBytes: 100)
    )))
    #expect(store.state.packDownloads["festival"] == .downloading(nil))
  }

  @Test @MainActor func inactiveSceneKeepsPackDownloadUntilBackground() async {
    var initial = FestivalFeature.State()
    initial.hasStarted = true
    initial.packDownloads["festival"] = .downloading(.init(receivedBytes: 40, totalBytes: 100))
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    #expect(store.state.packDownloads["festival"] == .downloading(.init(receivedBytes: 40, totalBytes: 100)))
    await store.send(.view(.backgrounded)) {
      $0.packDownloads = [:]
    }
  }

  @Test @MainActor func accountClearKeepsDownloadUntilAccountChangedCancelsIt() async {
    var initial = FestivalFeature.State()
    initial.hasSession = true
    initial.sessionUserID = "user-a"
    initial.packDownloads["festival"] = .downloading(.init(receivedBytes: 40, totalBytes: 100))
    initial.clearAccountData()
    #expect(initial.packDownloads["festival"] != nil)

    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }
    store.exhaustivity = .off
    await store.send(.view(.accountChanged)) {
      $0.packDownloads = [:]
      $0.hasSession = false
      $0.sessionUserID = nil
      $0.accountGeneration = 1
    }
  }

  @Test @MainActor func bookmarkReloadDoesNotCancelPublishedPackDownload() async {
    var initial = FestivalFeature.State()
    initial.bookedUserID = "user-a"
    initial.bookedFestivalIDs = ["festival"]
    initial.packDownloads["festival"] = .downloading(.init(receivedBytes: 40, totalBytes: 100))
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in userID == "user-a" ? ["festival"] : [] },
        save: { _, _ in }
      )
    }

    await store.send(.view(.reloadBookmarks(userID: nil))) {
      $0.bookedUserID = nil
      $0.bookedFestivalIDs = []
    }
    #expect(store.state.packDownloads["festival"] != nil)
    await store.send(.view(.reloadBookmarks(userID: "user-a"))) {
      $0.bookedUserID = "user-a"
      $0.bookedFestivalIDs = ["festival"]
    }
    #expect(store.state.packDownloads["festival"] != nil)
    await store.send(.view(.reloadBookmarks(userID: "user-b"))) {
      $0.bookedUserID = "user-b"
      $0.bookedFestivalIDs = []
    }
    #expect(store.state.packDownloads["festival"] != nil)
  }
}
