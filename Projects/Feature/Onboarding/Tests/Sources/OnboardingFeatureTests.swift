import ComposableArchitecture
import Testing
import UIKit
@testable import Onboarding

@MainActor
struct OnboardingFeatureTests {
  @Test func advancesThroughFourPagesAndCompletes() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }
    for page in 1...3 {
      await store.send(.view(.nextTapped)) { $0.page = page }
    }
    await store.send(.view(.nextTapped))
    await store.receive(\.delegate.completed)
  }

  @Test func pageSelectionClampsAndSkipCompletes() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }
    await store.send(.view(.pageChanged(99))) { $0.page = 3 }
    await store.send(.view(.skipTapped))
    await store.receive(\.delegate.completed)
  }

  @Test func downloadedIllustrationsLoadFromFeatureAssets() {
    let bundle = Bundle(for: OnboardingBundleMarker.self)
    for page in OnboardingPage.all {
      let image = UIImage(
        named: page.imageAsset.rawValue,
        in: bundle,
        compatibleWith: nil
      )
      #expect(image?.size == CGSize(width: 345, height: 431))
      #expect(image?.scale == 3)
    }
  }
}
