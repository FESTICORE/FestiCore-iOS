import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalOnlineDetailFeatureTests {
  @Test func onlineDetailLoadsWithoutDownloadingPack() async throws {
    let detail = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst","name":"온라인 축제","timetable":[{"id":"set_1","artist":"가수","startsAt":"2026-11-05T10:00:00Z"}]}"#.utf8)
    )
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.isLiveBoardVisible = true
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.festivalCatalogUseCase = MockFestivalCatalogUseCase(festivalDetail: { _ in detail })
      $0.festivalImageUseCase = MockFestivalImageUseCase(
        imageURL: { _ in nil },
        startPrefetch: { _ in },
        stopPrefetch: {}
      )
    }

    await store.send(.view(.onlineDetailOnAppear)) { $0.onlineDetailLoading = true }
    await store.receive(\.async.loadOnlineDetail)
    await store.receive(\.inner.onlineDetailLoaded) {
      $0.onlineDetail = detail
      $0.onlineDetailLoading = false
    }
    await store.finish()
    #expect(store.state.displayDocument?.performances.first?.id == "set_1")
    #expect(store.state.selectedPack == nil)
    #expect(store.state.cachedPacks.isEmpty)
    #expect(store.state.packDownloads.isEmpty)
  }
}
