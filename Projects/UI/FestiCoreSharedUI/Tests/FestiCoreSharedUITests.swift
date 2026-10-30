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

  @Test @MainActor func remoteImageCopiesContentModeWithoutChangingOriginal() {
    let original = FCRemoteImage(url: nil)
    let fitted = original.content(.fit)

    #expect(original.contentMode == .fill)
    #expect(fitted.contentMode == .fit)
    #expect(UIHostingController(rootView: fitted).view != nil)
  }

  @Test @MainActor func missingImageKeepsRequestedFrame() {
    let image = FCRemoteImage(url: nil)
      .frame(width: 84, height: 50)
    let controller = UIHostingController(rootView: image)

    #expect(controller.sizeThatFits(in: CGSize(width: 200, height: 200)) == CGSize(width: 84, height: 50))
  }

  @Test @MainActor func fittedRemoteImageKeepsCallerFrame() {
    let image = FCRemoteImage(url: nil)
      .content(.fit)
      .frame(width: 120, height: 80)
    let controller = UIHostingController(rootView: image)

    #expect(controller.sizeThatFits(in: CGSize(width: 200, height: 200)) == CGSize(width: 120, height: 80))
  }
}
