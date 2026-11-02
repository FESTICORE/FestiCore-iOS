import ComposableArchitecture
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


  @Test func svgDataBecomesImage() throws {
    let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="24" height="16"><rect width="24" height="16" fill="black"/></svg>"#
    let image = try #require(makeSVGImage(from: Data(svg.utf8)))

    #expect(image.size == CGSize(width: 24, height: 16))
  }

  @Test func nonSVGDataIsLeftToDefaultProcessor() {
    #expect(makeSVGImage(from: Data([0x89, 0x50, 0x4E, 0x47])) == nil)
  }

  @Test func logoutAlertUsesConfirmationStyle() {
    let alert = FCAlertState.logout()

    #expect(alert.title == "로그아웃")
    #expect(alert.confirmTitle == "로그아웃")
    #expect(alert.style == .confirmation)
    #expect(alert == .logout())
  }

  @Test @MainActor func modalHostsPresentedStore() {
    let store = Store(initialState: FCAlertState.logout()) { FCConfirmAlert() }
    let view = Color.clear.fcModal(.constant(store)) { modalStore in
      Text(modalStore.withState(\.title))
    }

    #expect(UIHostingController(rootView: view).view != nil)
  }
}
