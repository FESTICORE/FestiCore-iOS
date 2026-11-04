import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalPackDownloadFeatureTests {
  @Test @MainActor func downloadButtonTracksMeasuredProgressAndCachedResult() async {
    let festival = FestivalCatalogItem(
      id: "festival", name: "축제", firstDate: "2099-11-21", packVersion: 2
    )
    let pack = CachedFestivalPack(
      festivalID: "festival", packVersion: 2, etag: "v2", pack: Data("{}".utf8)
    )
    var initial = FestivalFeature.State()
    initial.catalog = [festival]
    initial.bookedFestivalIDs = ["festival"]
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

  @Test @MainActor func unbookedFestivalCannotDownload() async {
    var initial = FestivalFeature.State()
    initial.catalog = [FestivalCatalogItem(id: "festival", name: "축제", firstDate: "2099-11-21", packVersion: 2)]
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
}
