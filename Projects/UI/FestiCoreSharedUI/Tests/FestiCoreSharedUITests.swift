import SwiftUI
import Testing
@testable import FestiCoreSharedUI

struct FestiCoreSharedUITests {
  @Test @MainActor func sectionHostsFeatureContent() {
    let section = FestiCoreSection("Festival") {
      Text("Upcoming")
    }
    let controller = UIHostingController(rootView: section)
    #expect(controller.view != nil)
  }
}
