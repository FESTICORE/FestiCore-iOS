import ComposableArchitecture
import FestivalDomainInterface
import Testing
@testable import Festival

struct FestivalBookmarkFeatureTests {
  @Test @MainActor func bookmarkTapEmitsIntentWithoutWriting() async {
    let festival = FestivalCatalogItem(id: "festival", name: "축제", packVersion: 0)
    var initial = FestivalFeature.State()
    initial.catalog = [festival]
    let store = TestStore(initialState: initial) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.view(.toggleBookedFestival("festival")))
    await store.receive(\.delegate.bookmarkRequested)
    #expect(store.state.bookedFestivalIDs.isEmpty)
  }
}
