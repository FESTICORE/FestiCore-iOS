import Testing
import UIKit
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
    #expect(FestiCoreTypography.pointDisplay.fontFamily == "Bagel Fat One")
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
