import ComposableArchitecture
import Foundation
import Testing
@testable import Web

@MainActor
struct WebFeatureTests {
  private let url = URL(string: "https://festicore.app/terms")!

  @Test func firstAppearStartsOneLoadAndFinishes() async {
    let store = TestStore(initialState: WebFeature.State(url: url, title: "서비스 이용약관")) { WebFeature() }

    await store.send(.view(.onAppear)) { $0.loadID = 1 }
    await store.send(.view(.onAppear))
    await store.send(.view(.loadFinished(loadID: 1))) { $0.phase = .loaded }
  }

  @Test func retryStartsNewLoadAndIgnoresStaleCallbacks() async {
    let store = TestStore(initialState: WebFeature.State(url: url, title: "약관")) { WebFeature() }

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

  @Test func closeAsksParentToDismiss() async {
    let store = TestStore(initialState: WebFeature.State(url: url, title: "약관")) { WebFeature() }

    await store.send(.view(.closeTapped))
    await store.receive(\.delegate.close)
  }
}
