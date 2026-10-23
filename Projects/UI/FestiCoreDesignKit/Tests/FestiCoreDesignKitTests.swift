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

    for family in [PretendardFontFamily.regular, .medium, .bold] {
      let font = UIFont.pretendardFontFamily(family: family, size: 17)
      #expect(font.fontName == family.postScriptName)
      #expect(UIFont(name: family.postScriptName, size: 17) != nil)
      _ = Font.pretendardFontFamily(family: family, size: 17)
    }
  }

  @Test @MainActor func primaryColorTracksSystemAppearance() {
    let light = FestiCoreSemanticColor.primaryNormal.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let dark = FestiCoreSemanticColor.primaryNormal.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    #expect(light.getRed() == 0x11)
    #expect(dark.getRed() == 0xC6)
  }

  @Test @MainActor func layoutAndTypographyMatchTokenSnapshot() {
    #expect(FestiCoreSpacing.marginM12 == 12)
    #expect(FestiCoreRadius.r12 == 12)
    #expect(FestiCoreState.disabledOpacity == 0.3)
    #expect(FestiCoreTypography.baseBodyRegular.size == 17)
    #expect(FestiCoreTypography.baseBodyRegular.lineHeight == 1.529)
    let body = FestiCoreTypography.baseBodyRegular
    #expect(body.resolvedFont.fontName == PretendardFontFamily.regular.postScriptName)
    #expect(abs(body.resolvedFont.lineHeight + body.resolvedLineSpacing - body.size * body.lineHeight) < 0.01)
    #expect(FestiCoreTypography.pointDisplay.fontFamily == "Bagel Fat One")
    #expect(FestiCoreTypography.pointDisplay.resolvedFont.fontName == "BagelFatOne-Regular")
  }

  @Test @MainActor func tokensComposeWithSwiftUIModifiers() {
    let label = Text("Festival")
      .festiCoreTextStyle(FestiCoreTypography.baseBodyRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .padding(FestiCoreSpacing.marginM12)
    let controller = UIHostingController(rootView: label)
    #expect(controller.view != nil)

    let styled = Rectangle().foregroundStyle(.labelNormal)
    let shapeController = UIHostingController(rootView: styled)
    #expect(shapeController.view != nil)
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
