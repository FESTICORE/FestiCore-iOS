//
//  FestiCoreDesignKitTests.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import Testing
import UIKit
import SwiftUI
@testable import FestiCoreDesignKit

struct FestiCoreDesignKitTests {
  @Test func pretendardRegistersForUIKitAndSwiftUI() {
    PretendardFontFamily.registerFonts()
    PretendardFontFamily.registerFonts()

    for family in [PretendardFontFamily.Regular, .Medium, .Bold] {
      let font = UIFont.pretendardFontFamily(family: family, size: 17)
      let fontName = "PretendardVariable-\(family)"
      #expect(font.fontName == fontName)
      #expect(UIFont(name: fontName, size: 17) != nil)
      _ = Font.pretendardFontFamily(family: family, size: 17)
    }
  }

  @Test @MainActor func primaryColorTracksSystemAppearance() {
    let light = FestiCoreSemanticColor.primaryNormal.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let dark = FestiCoreSemanticColor.primaryNormal.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    #expect(light.getRed() == 0x11)
    #expect(dark.getRed() == 0xC6)
  }

  @Test @MainActor func swiftUISemanticColorsTrackColorScheme() {
    var light = EnvironmentValues()
    light.colorScheme = .light
    var dark = EnvironmentValues()
    dark.colorScheme = .dark

    let lightPrimary = Color.primaryNormal.resolve(in: light)
    let darkPrimary = Color.primaryNormal.resolve(in: dark)
    #expect(lightPrimary.red.isApproximately(0x11 / 255.0))
    #expect(darkPrimary.red.isApproximately(0xC6 / 255.0))

    let lightLabel = Color.labelNormal.resolve(in: light)
    let darkLabel = Color.labelNormal.resolve(in: dark)
    #expect(lightLabel.red.isApproximately(0x11 / 255.0))
    #expect(darkLabel.red.isApproximately(1))

    let lightFill = Color.fillNormal.resolve(in: light)
    let darkFill = Color.fillNormal.resolve(in: dark)
    #expect(lightFill.opacity.isApproximately(1))
    #expect(darkFill.opacity.isApproximately(0x1A / 255.0))

    #expect(Color.staticWhite.resolve(in: light) == Color.staticWhite.resolve(in: dark))
  }

  @Test @MainActor func layoutAndTypographyMatchTokenSnapshot() {
    #expect(FestiCoreSpacing.marginM12 == 12)
    #expect(FestiCoreRadius.r12 == 12)
    #expect(FestiCoreState.disabledOpacity == 0.3)
    #expect(FestiCoreTextStyle.baseBodyRegular.size == 17)
    #expect(FestiCoreTextStyle.baseBodyRegular.lineHeight == 1.529)
    let body = FestiCoreTextStyle.baseBodyRegular
    #expect(body.resolvedFont.fontName == "PretendardVariable-Regular")
    #expect(abs(body.resolvedFont.lineHeight + body.resolvedLineSpacing - body.size * body.lineHeight) < 0.01)
    let point = FestiCoreTextStyle.pointDisplay
    #expect(point.fontFamily == .Regular)
    #expect(point.resolvedFont.fontName == "PretendardVariable-Regular")
    #expect(point.size == 40)
  }

  @Test @MainActor func tokensComposeWithSwiftUIModifiers() {
    let label = Text("Festival")
      .festiCoreTextStyle(.baseBodyRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .padding(FestiCoreSpacing.marginM12)
    let controller = UIHostingController(rootView: label)
    #expect(controller.view != nil)

    let styled = Rectangle().foregroundStyle(.labelNormal)
    let shapeController = UIHostingController(rootView: styled)
    #expect(shapeController.view != nil)
  }

  @Test @MainActor func typographyModifierUsesFixedTokenSizeAcrossContentSizeCategories() {
    let style = FestiCoreTextStyle.baseBodyRegular
    let standard = UIHostingController(rootView: Text("Festival")
      .festiCoreTextStyle(style)
      .environment(\.sizeCategory, .large))
    let accessibility = UIHostingController(rootView: Text("Festival")
      .festiCoreTextStyle(style)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge))

    #expect(standard.view.sizeThatFits(CGSize(width: 300, height: 300)) ==
      accessibility.view.sizeThatFits(CGSize(width: 300, height: 300)))
  }

  @Test @MainActor func missingImageAssetUsesAttendanceFallback() {
    let asset = ImageAsset(rawValue: "missing-image")
    #expect(UIImage(asset) == nil)
    #expect(UIImage(assetName: asset.rawValue) == nil)
    let controller = UIHostingController(rootView: Image(asset: asset))
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

private extension Float {
  func isApproximately(_ expected: Float) -> Bool {
    abs(self - expected) < 0.01
  }
}
