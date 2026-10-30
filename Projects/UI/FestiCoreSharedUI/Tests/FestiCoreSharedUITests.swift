import SwiftUI
import Testing
@testable import FestiCoreSharedUI

struct FestiCoreSharedUITests {
  @Test @MainActor func delayedDismissalCannotCloseReplacementSheet() {
    let box = TestSheetBox()
    let binding = Binding<TestSheet?>(get: { box.item }, set: { box.item = $0 })

    box.item = .onboarding
    FCSheetModifier<TestSheet, Text>.completeDismissal(of: .login, item: binding)
    #expect(box.item == .onboarding)

    FCSheetModifier<TestSheet, Text>.completeDismissal(of: .onboarding, item: binding)
    #expect(box.item == nil)
  }

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


  @Test func svgDataBecomesImage() throws {
    let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="24" height="16"><rect width="24" height="16" fill="black"/></svg>"#
    let image = try #require(makeSVGImage(from: Data(svg.utf8)))

    #expect(image.size == CGSize(width: 24, height: 16))
  }

  @Test func nonSVGDataIsLeftToDefaultProcessor() {
    #expect(makeSVGImage(from: Data([0x89, 0x50, 0x4E, 0x47])) == nil)
  }
}

private enum TestSheet: Identifiable {
  case login
  case onboarding

  var id: Self { self }
}

@MainActor
private final class TestSheetBox {
  var item: TestSheet? = .login
}
