//
//  FestiCoreDesignKitTests.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import Observation
import Testing
import UIKit
import SwiftUI
@testable import FestiCoreDesignKit

@Suite(.serialized)
struct FestiCoreDesignKitTests {
  @Test @MainActor func delayedDismissalCannotCloseReplacementSheet() {
    let box = TestSheetBox()
    let binding = Binding<TestSheet?>(get: { box.item }, set: { box.item = $0 })

    box.item = .onboarding
    FCSheetModifier<TestSheet, Text, EmptyView>.completeDismissal(of: .login, item: binding)
    #expect(box.item == .onboarding)

    FCSheetModifier<TestSheet, Text, EmptyView>.completeDismissal(of: .onboarding, item: binding)
    #expect(box.item == nil)
  }

  @Test @MainActor func pendingDismissalSurvivesReopenWhileMounted() async throws {
    let harness = SheetTestHarness(conditional: false)
    defer { harness.close() }
    try await harness.render()
    let dismiss = try #require(harness.box.dismiss)
    let clock = ContinuousClock()
    let requested = clock.now

    dismiss()
    try await harness.render()
    harness.box.item = nil
    try await harness.render()
    harness.box.item = .login
    try await harness.render()
    #expect(requested.duration(to: clock.now) < SheetTestTiming.preDeadlineLimit)

    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == .login)
  }

  @Test @MainActor func pendingDismissalIsCancelledWhenModifierIsRemoved() async throws {
    let harness = SheetTestHarness(conditional: true)
    defer { harness.close() }
    try await harness.render()
    let dismiss = try #require(harness.box.dismiss)
    let clock = ContinuousClock()
    let requested = clock.now

    dismiss()
    try await harness.render()
    harness.box.item = nil
    try await harness.render()
    harness.box.item = .login
    try await harness.render()
    #expect(requested.duration(to: clock.now) < SheetTestTiming.preDeadlineLimit)

    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == .login)
  }

  @Test @MainActor func pendingDismissalKeepsReplacementSheet() async throws {
    let harness = SheetTestHarness(conditional: false)
    defer { harness.close() }
    try await harness.render()
    let dismiss = try #require(harness.box.dismiss)
    let clock = ContinuousClock()
    let requested = clock.now

    dismiss()
    try await harness.render()
    harness.box.item = .onboarding
    try await harness.render()
    #expect(requested.duration(to: clock.now) < SheetTestTiming.preDeadlineLimit)

    for _ in 0..<3 { try await harness.render() }
    #expect(requested.duration(to: clock.now) < SheetTestTiming.preDeadlineLimit)
    let beforeDeadline = try #require(harness.box.sheetFrame)
    #expect(beforeDeadline.minY < harness.window.bounds.height)

    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == .onboarding)
    let afterDeadline = try #require(harness.box.sheetFrame)
    #expect(afterDeadline.minY < harness.window.bounds.height)
  }

  @Test @MainActor func replacementWithoutPendingDismissalKeepsPosition() async throws {
    let harness = SheetTestHarness(conditional: false)
    defer { harness.close() }
    for _ in 0..<5 { try await harness.render() }
    let beforeReplacement = try #require(harness.box.sheetFrame)

    harness.box.item = .onboarding
    try await harness.render()

    let afterReplacement = try #require(harness.box.sheetFrame)
    #expect(afterReplacement.minY == beforeReplacement.minY)
  }

  @Test @MainActor func delayedDismissalClosesUnchangedSheet() async throws {
    let harness = SheetTestHarness(conditional: false)
    defer { harness.close() }
    try await harness.render()
    let dismiss = try #require(harness.box.dismiss)

    dismiss()
    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == nil)
  }

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
      .festiCoreFont(.baseBodyRegular)
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
      .festiCoreFont(style)
      .environment(\.sizeCategory, .large))
    let accessibility = UIHostingController(rootView: Text("Festival")
      .festiCoreFont(style)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge))

    #expect(standard.view.sizeThatFits(CGSize(width: 300, height: 300)) ==
      accessibility.view.sizeThatFits(CGSize(width: 300, height: 300)))
  }

  @Test func paginationMarksCurrentPageFromOne() {
    #expect(FCPagination(current: 1).dotStates == [true, false, false, false])
    #expect(FCPagination(current: 2).dotStates == [false, true, false, false])
    #expect(FCPagination(current: 3).dotStates == [false, false, true, false])
    #expect(FCPagination(current: 4).dotStates == [false, false, false, true])
    #expect(FCPagination(current: 2).accessibilityText == "페이지 2/4")
  }

  @Test func paginationClampsOutOfRangePage() {
    #expect(FCPagination(current: 0).dotStates == [true, false, false, false])
    #expect(FCPagination(current: 0).accessibilityText == "페이지 1/4")
    #expect(FCPagination(current: 5).dotStates == [false, false, false, true])
    #expect(FCPagination(current: 5).accessibilityText == "페이지 4/4")
  }

  @Test func paginationDrawsNothingWithoutPages() {
    #expect(FCPagination(count: 0, current: 1).dotStates.isEmpty)
    #expect(FCPagination(count: 0, current: 1).accessibilityText == nil)
    #expect(FCPagination(count: -1, current: 1).dotStates.isEmpty)
    #expect(FCPagination(count: -1, current: 1).accessibilityText == nil)
  }

  @Test @MainActor func flagCardFollowButtonMatchesFigmaVariants() {
    #expect(FCFlagCard<FCThumbnail>.followStyle(isFollowing: false) == .inverse)
    #expect(FCFlagCard<FCThumbnail>.followStyle(isFollowing: true) == .secondary)
    let card = FCFlagCard(
      name: "호락호락",
      status: nil,
      zone: "리벳 스테이지 앞 왼쪽",
      context: .directory(followers: "팔로워 1,284", tags: ["슬램"], isFollowing: false) {}
    )
    #expect(card.isFollowEnabled)
    #expect(card.followEnabled(false).isFollowEnabled == false)
  }

  @Test @MainActor func missingImageAssetUsesAttendanceFallback() {
    let asset = ImageAsset(rawValue: "missing-image")
    #expect(UIImage(asset) == nil)
    #expect(UIImage(assetName: asset.rawValue) == nil)
    let controller = UIHostingController(rootView: Image(asset: asset))
    #expect(controller.view != nil)
  }
}

private enum SheetTestTiming {
  static let dismissalDelay: Double = 3.0
  static let preDeadlineLimit: Duration = .milliseconds(2500)
  static let resultWait: Duration = .milliseconds(3500)
  static let renderWait: Duration = .milliseconds(100)
}

private enum TestSheet: Identifiable {
  case login
  case onboarding

  var id: Self { self }
}

@MainActor
@Observable
private final class TestSheetBox {
  var item: TestSheet? = .login
  var dismiss: (() -> Void)?
  @ObservationIgnored var sheetFrame: CGRect?
}

@MainActor
private final class SheetTestHarness {
  let box = TestSheetBox()
  let controller: UIHostingController<SheetTestHost>
  let window: UIWindow

  init(conditional: Bool) {
    controller = UIHostingController(rootView: SheetTestHost(box: box, conditional: conditional))
    window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = controller
    window.makeKeyAndVisible()
  }

  func render() async throws {
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
  }

  func close() {
    box.dismiss = nil
    window.isHidden = true
    window.rootViewController = nil
  }
}

private struct SheetTestHost: View {
  let box: TestSheetBox
  let conditional: Bool

  var body: some View {
    Group {
      if conditional && box.item == nil {
        Color.clear
      } else {
        Color.clear.presentFCSheet(item: Binding(
          get: { box.item },
          set: { box.item = $0 }
        )) { _ in
          SheetTestContent(box: box)
        }
      }
    }
    .environment(\.fcSheetDismissalDelay, SheetTestTiming.dismissalDelay)
  }
}

private struct SheetTestContent: View {
  @Environment(\.fcSheetDismiss) private var dismiss
  let box: TestSheetBox

  var body: some View {
    Text("Sheet")
      .onAppear { box.dismiss = dismiss }
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { box.sheetFrame = $0 }
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
