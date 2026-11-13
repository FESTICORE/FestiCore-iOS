import ComposableArchitecture
import FestiCoreAnalyticsInterface
import Foundation
import Testing
@testable import Web

@MainActor
struct WebFeatureTests {
  private let url = URL(string: "https://festicore.app/terms")!

  @Test func firstAppearStartsOneLoadAndFinishes() async {
    let analytics = LockIsolated<[AnalyticsEvent]>([])
    let store = TestStore(initialState: WebFeature.State(
      url: url,
      title: "서비스 이용약관"
    )) {
      WebFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { event in analytics.withValue { $0.append(event) } }
    }

    await store.send(.view(.onAppear)) { $0.loadID = 1 }
    await store.send(.view(.onAppear))
    await store.send(.view(.loadFinished(loadID: 1))) { $0.phase = .loaded }
    #expect(analytics.value == [.screenView(
      screen: .web,
      referrer: nil
    )])
  }

  @Test func retryStartsNewLoadAndIgnoresStaleCallbacks() async {
    let store = TestStore(initialState: WebFeature.State(
      url: url,
      title: "약관"
    )) {
      WebFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
    }

    await store.send(.view(.onAppear)) { $0.loadID = 1 }
    await store.send(.view(.loadFailed(loadID: 1))) { $0.phase = .failed }
    await store.send(.view(.retryTapped)) {
      $0.loadID = 2
      $0.phase = .loading
    }
    await store.send(.view(.loadFinished(loadID: 1)))
    await store.send(.view(.loadFailed(loadID: 1)))
    await store.send(.view(.loadFinished(loadID: 2))) { $0.phase = .loaded }
  }

  @Test func initialStateStartsLoadingWithoutRequest() {
    let state = WebFeature.State(url: url, title: "개인정보 수집 · 이용")
    #expect(state.phase == .loading)
    #expect(state.loadID == 0)
    #expect(state.id == url)
  }

  @Test func failureWithoutRetryKeepsFailedUntilRetried() async {
    let store = TestStore(initialState: WebFeature.State(
      url: url,
      title: "약관"
    )) {
      WebFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
    }

    await store.send(.view(.onAppear)) { $0.loadID = 1 }
    await store.send(.view(.loadFailed(loadID: 1))) { $0.phase = .failed }
    await store.send(.view(.onAppear))
  }

  @Test func defaultScopeIsDocumentAndBookingKeepsScope() {
    #expect(WebFeature.State(
      url: url,
      title: "약관"
    ).navigationScope == .document)
    #expect(WebFeature.State(
      url: url,
      title: "티켓 예매",
      navigationScope: .booking
    ).navigationScope == .booking)
  }

  @Test func externalURLOpensOutsideWebView() async throws {
    let opened = LockIsolated<[URL]>([])
    let payment = try #require(URL(string: "ispmobile://TID=1234"))
    let store = TestStore(initialState: WebFeature.State(
      url: url,
      title: "티켓 예매",
      navigationScope: .booking
    )) {
      WebFeature()
    } withDependencies: {
      $0.openURL = .init { url in
        opened.withValue { $0.append(url) }
        return true
      }
    }

    await store.send(.view(.externalURLRequested(payment)))
    await store.finish()
    #expect(opened.value == [payment])
  }

  @Test func closeAsksParentToDismiss() async {
    let store = TestStore(initialState: WebFeature.State(url: url, title: "약관")) { WebFeature() }

    await store.send(.view(.closeTapped))
    await store.receive(\.delegate.backToRoot)
  }
}
