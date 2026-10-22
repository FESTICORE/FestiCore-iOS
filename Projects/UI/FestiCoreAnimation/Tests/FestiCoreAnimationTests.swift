import SwiftUI
import Testing
@testable import FestiCoreAnimation

struct FestiCoreAnimationTests {
  @Test @MainActor func viewAcceptsCallerBundleAndPausedBinding() {
    let view = FestiCoreAnimationView(name: "loading.gif", bundle: .main, isAnimating: .constant(false))
    let controller = UIHostingController(rootView: view)
    #expect(controller.view != nil)
  }
}
