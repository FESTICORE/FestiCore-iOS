import Testing
import UIKit
import SwiftUI
@testable import FestiCoreDesignSystem

struct FestiCoreDesignSystemTests {
  @Test @MainActor func primaryColorTracksSystemAppearance() {
    let light = FestiCoreColor.primaryNormal.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let dark = FestiCoreColor.primaryNormal.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    #expect(light.getRed() == 0x11)
    #expect(dark.getRed() == 0xC6)
  }

  @Test @MainActor func layoutAndTypographyMatchTokenSnapshot() {
    #expect(FestiCoreSpacing.marginM12 == 12)
    #expect(FestiCoreRadius.r12 == 12)
    #expect(FestiCoreTypography.baseBodyRegular.size == 17)
    #expect(FestiCoreTypography.baseBodyRegular.lineHeight == 1.529)
    let body = FestiCoreTypography.baseBodyRegular
    #expect(abs(body.font.lineHeight + body.lineSpacing - body.size * body.lineHeight) < 0.01)
    #expect(FestiCoreTypography.pointDisplay.fontFamily == "Bagel Fat One")
  }

  @Test @MainActor func tokensComposeWithSwiftUIModifiers() {
    let label = Text("Festival")
      .festiCoreTextStyle(FestiCoreTypography.baseBodyRegular)
      .foregroundStyle(Color.festiCore(FestiCoreColor.labelNormal))
      .padding(FestiCoreSpacing.marginM12)
    let controller = UIHostingController(rootView: label)
    #expect(controller.view != nil)
  }
}

private extension UIColor {
  func getRed() -> Int {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return Int((red * 255).rounded())
  }
}
