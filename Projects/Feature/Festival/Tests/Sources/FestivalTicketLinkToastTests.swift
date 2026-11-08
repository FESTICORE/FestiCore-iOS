import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
import Web
@testable import Festival

/// 목록 카드의 티켓 예매 링크(#375). 링크가 있으면 앱 안 웹 화면, 없으면 안내 토스트를 띄운다.
@MainActor
struct FestivalTicketLinkToastTests {
  @Test("티켓 링크가 없으면 안내 토스트를 2초 동안 보인다")
  func missingTicketLinkShowsToastForTwoSeconds() async {
    let clock = TestClock()
    let store = TestStore(initialState: state(ticketLinks: [])) {
      FestivalFeature()
    } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.continuousClock = clock
    }

    await store.send(.view(.ticketLinkTapped(festivalID: "festival"))) {
      $0.toast = .ticketLinkMissing
      $0.toastRevision = 1
    }
    await store.receive(\.async.expireToast)
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.toastExpired) {
      $0.toast = nil
    }
  }

  @Test("https 티켓 링크는 예매 범위의 앱 안 웹 화면으로 열고, 닫으면 목록으로 돌아온다")
  func ticketLinkOpensInAppWebAndCloses() async throws {
    let url = try #require(URL(string: "https://ticket.melon.com/performance/1"))
    let store = TestStore(initialState: state(ticketLinks: [
      FestivalTicketLink(
        label: "멜론티켓",
        url: url
      )
    ])) {
      FestivalFeature()
    } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.view(.ticketLinkTapped(festivalID: "festival"))) {
      $0.ticket = WebFeature.State(
        url: url,
        title: "티켓 예매",
        navigationScope: .booking
      )
    }
    await store.send(.ticket(.presented(.view(.closeTapped))))
    await store.receive(\.ticket.presented.delegate.backToRoot) {
      $0.ticket = nil
    }
  }

  private func state(ticketLinks: [FestivalTicketLink]) -> FestivalFeature.State {
    var state = FestivalFeature.State()
    state.catalog = [FestivalCatalogItem(
      id: "festival",
      name: "축제",
      packVersion: 1,
      ticketLinks: ticketLinks
    )]
    return state
  }
}
