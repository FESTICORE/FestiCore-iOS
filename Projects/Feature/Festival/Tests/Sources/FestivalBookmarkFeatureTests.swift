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
    #expect(store.state.toast == nil)
  }

  @Test @MainActor func savedBookmarkShowsRepeatableToastAndExpires() async {
    let clock = TestClock()
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.continuousClock = clock
    }

    await store.send(.view(.bookmarkSaved(id: "festival", booked: true))) {
      $0.toast = .bookmarked
      $0.toastRevision = 1
    }
    await store.receive(\.async.expireToast)
    await store.send(.view(.bookmarkSaved(id: "festival", booked: true))) {
      $0.toastRevision = 2
    }
    await store.receive(\.async.expireToast)
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.toastExpired) {
      $0.toast = nil
    }
    await store.send(.view(.bookmarkSaved(id: "festival", booked: false))) {
      $0.toast = .unbookmarked
      $0.toastRevision = 3
    }
    await store.receive(\.async.expireToast)
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.toastExpired) {
      $0.toast = nil
    }
  }
}
