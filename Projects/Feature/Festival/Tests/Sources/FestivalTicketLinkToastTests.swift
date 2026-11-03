import ComposableArchitecture
import Testing
@testable import Festival

@MainActor
struct FestivalTicketLinkToastTests {
  @Test func missingTicketLinkShowsToastForTwoSeconds() async {
    let clock = TestClock()
    let store = TestStore(initialState: FestivalFeature.State()) {
      FestivalFeature()
    } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.continuousClock = clock
    }

    await store.send(.view(.ticketLinkMissing)) {
      $0.toast = .ticketLinkMissing
      $0.toastRevision = 1
    }
    await store.receive(\.async.expireToast)
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.toastExpired) {
      $0.toast = nil
    }
  }
}
