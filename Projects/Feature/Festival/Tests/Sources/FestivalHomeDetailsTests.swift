import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalHomeDetailsTests {
  @Test("선택한 팩의 귀가 정보를 기존 Domain UseCase에서 읽는다")
  func loadsCachedHomeDetails() async {
    let pack = CachedFestivalPack(festivalID: "fst", packVersion: 1, etag: "v1", pack: Data())
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.cachedPacks["fst"] = pack
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(packDetail: { id in
        #expect(id == "fst")
        return nil
      })
    }

    await store.send(.async(.loadHomeDetails("fst"))) {
      $0.homeDetails = .loading("fst")
    }
    await store.receive(\.inner.homeDetailsLoaded) {
      $0.homeDetails = .loaded("fst", nil)
    }
  }

  @Test("이전 축제의 귀가 응답은 현재 화면을 바꾸지 않는다")
  func ignoresStaleHomeDetails() async {
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "new")) {
      FestivalFeature()
    }
    await store.send(.inner(.homeDetailsLoaded("old", .init(lastTrainAt: "23:52"))))
    #expect(store.state.homeDetails == .idle)
  }
}
