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
    let reopenedFrame = try #require(harness.box.sheetFrame)
    #expect(reopenedFrame.minY < harness.window.bounds.height)
  }

  @Test @MainActor func pendingDismissalCannotCloseRapidConditionalReopen() async throws {
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
    #expect(harness.box.sheetDisappearCount == 1)
    harness.box.item = .login
    try await harness.render()
    #expect(requested.duration(to: clock.now) < SheetTestTiming.preDeadlineLimit)

    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == .login)
    let reopenedFrame = try #require(harness.box.sheetFrame)
    #expect(reopenedFrame.minY < harness.window.bounds.height)

    let reopenedDismiss = try #require(harness.box.dismiss)
    reopenedDismiss()
    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == nil)
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
    // 제거 애니메이션 도중 재열면 SwiftUI가 제거를 취소할 수 있으므로 실제 수명 종료를 확인한다.
    let removalDeadline = requested.advanced(by: SheetTestTiming.preDeadlineLimit)
    while harness.box.modifierDisappearCount == 0, clock.now < removalDeadline {
      try await harness.render()
    }
    try #require(harness.box.modifierDisappearCount >= 1)
    harness.box.item = .login
    try await harness.render()
    #expect(requested.duration(to: clock.now) < SheetTestTiming.preDeadlineLimit)

    try await Task.sleep(for: SheetTestTiming.resultWait)
    #expect(harness.box.item == .login)
  }

  @Test @MainActor func removingModifierCancelsDismissalWhileItemRemainsPresented() async throws {
    let harness = SheetTestHarness(conditional: true)
    defer { harness.close() }
    try await harness.render()
    let dismiss = try #require(harness.box.dismiss)
    let clock = ContinuousClock()
    let requested = clock.now

    dismiss()
    harness.box.isModifierMounted = false
    try await harness.render()
    #expect(harness.box.modifierDisappearCount == 1)
    #expect(harness.box.item == .login)
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

  @Test @MainActor func presentingSheetKeepsBackgroundPosition() async throws {
    let harness = SheetTestHarness(conditional: false)
    defer { harness.close() }
    harness.box.item = nil
    try await harness.render()
    let beforePresentation = try #require(harness.box.backgroundFrame)

    harness.box.item = .login
    for _ in 0..<5 { try await harness.render() }

    let afterPresentation = try #require(harness.box.backgroundFrame)
    #expect(afterPresentation == beforePresentation)
    #expect(harness.box.sheetFrame != nil)
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

  @Test @MainActor func modalPresenceIsReportedToAncestors() async throws {
    let box = ModalPresenceBox()
    let controller = UIHostingController(rootView: ModalPresenceHost(box: box))
    let window = UIWindow(frame: CGRect(
      x: 0,
      y: 0,
      width: 390,
      height: 844
    ))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
    #expect(!box.isPresented)

    box.inner = .login
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
    #expect(box.isPresented)

    box.inner = nil
    box.outer = .onboarding
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
    #expect(box.isPresented)

    box.outer = nil
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
    #expect(!box.isPresented)
  }

  @Test @MainActor func modalInPushedScreenIsReportedOutsideNavigationStack() async throws {
    let box = ModalPresenceBox()
    let controller = UIHostingController(rootView: PushedModalPresenceHost(box: box))
    let window = UIWindow(frame: CGRect(
      x: 0,
      y: 0,
      width: 390,
      height: 844
    ))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    box.path = [1]
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
    #expect(!box.isPresented)

    box.inner = .login
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: SheetTestTiming.renderWait)
    #expect(box.isPresented)
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

  @Test @MainActor func pointStylesRegisterBagelForRenderingAndMetrics() throws {
    let styles: [FestiCoreTextStyle] = [.pointDisplay, .pointHeading, .pointLabel, .pointTitle]
    for style in styles {
      let resolved = style.resolvedFont
      let registered = try #require(UIFont(
        name: "BagelFatOne-Regular",
        size: style.size
      ))
      #expect(resolved.fontName == registered.fontName)
      #expect(resolved.pointSize == style.size)
      #expect(resolved.lineHeight == registered.lineHeight)
      #expect(style.resolvedFont == resolved)

      let renderer = ImageRenderer(content: Text("오늘도 즐거웠나요?").festiCoreFont(style))
      #expect(renderer.uiImage != nil)
    }
    #expect(FestiCoreTextStyle.baseBodyRegular.resolvedFont.fontName == "PretendardVariable-Regular")
  }

  @Test @MainActor func primaryColorTracksSystemAppearance() {
    let light = FestiCoreSemanticColor.primaryNormal.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let dark = FestiCoreSemanticColor.primaryNormal.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    #expect(light.getRed() == 0x11)
    #expect(dark.getRed() == 0xC6)
  }

  @Test @MainActor func appleLoginLogoRendersWithDarkModeContrast() throws {
    PretendardFontFamily.registerFonts()
    let renderer = ImageRenderer(content: FCLoginButton(.apple) {}
      .frame(width: 320)
      .environment(\.colorScheme, .dark))
    renderer.scale = 1
    let image = try #require(renderer.uiImage)
    let cgImage = try #require(image.cgImage)
    #expect(cgImage.width == 320)
    #expect(cgImage.height == 52)
    #expect(cgImage.bitsPerPixel == 32)

    let data = try #require(cgImage.dataProvider?.data)
    let bytes = try #require(CFDataGetBytePtr(data))
    let labelWidth = ("Apple로 계속" as NSString).size(withAttributes: [
      .font: FestiCoreTextStyle.baseCalloutBold.resolvedFont
    ]).width
    let iconLeading = (320 - (16 + FestiCoreSpacing.paddingP8 + labelWidth)) / 2
    let iconRange = (Int(iconLeading) - 2)..<(Int(iconLeading) + 18)
    let iconPixels = (16..<36).flatMap { y in
      iconRange.map { x in
        let offset = y * cgImage.bytesPerRow + x * 4
        let alphaFirst = bytes[offset] > 0xC0
          && bytes[offset + 1] < 0x80 && bytes[offset + 2] < 0x80 && bytes[offset + 3] < 0x80
        let alphaLast = bytes[offset + 3] > 0xC0
          && bytes[offset] < 0x80 && bytes[offset + 1] < 0x80 && bytes[offset + 2] < 0x80
        return alphaFirst || alphaLast
      }
    }
    #expect(iconPixels.filter { $0 }.count > 12)
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
    #expect(point.resolvedFont.fontName == "BagelFatOne-Regular")
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
  var isModifierMounted = true
  @ObservationIgnored var modifierDisappearCount = 0
  var dismiss: (() -> Void)?
  @ObservationIgnored var backgroundFrame: CGRect?
  @ObservationIgnored var sheetFrame: CGRect?
  @ObservationIgnored var sheetDisappearCount = 0
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

@MainActor
@Observable
private final class ModalPresenceBox {
  var outer: TestSheet?
  var inner: TestSheet?
  var path: [Int] = []
  @ObservationIgnored var isPresented = false
}

/// push된 화면 안 시트가 NavigationStack 바깥에서 감지되는지 본다(탭 화면의 push 경로와 같은 구조).
private struct PushedModalPresenceHost: View {
  @Bindable var box: ModalPresenceBox

  var body: some View {
    NavigationStack(path: $box.path) {
      Color.clear
        .navigationDestination(for: Int.self) { _ in
          Color.clear
            .fcModal(item: Binding(
              get: { box.inner },
              set: { box.inner = $0 }
            )) { _ in
              Text("Pushed")
            }
        }
    }
    .onPreferenceChange(FCModalPresentedKey.self) { box.isPresented = $0 }
  }
}

/// 바깥 시트와 화면 안쪽 시트 중 하나라도 뜨면 상위에서 읽는 값이 true가 되는지 본다.
private struct ModalPresenceHost: View {
  let box: ModalPresenceBox

  var body: some View {
    ZStack {
      Color.clear
        .fcModal(item: Binding(
          get: { box.inner },
          set: { box.inner = $0 }
        )) { _ in
          Text("Inner")
        }
    }
    .fcModal(item: Binding(
      get: { box.outer },
      set: { box.outer = $0 }
    )) { _ in
      Text("Outer")
    }
    .onPreferenceChange(FCModalPresentedKey.self) { box.isPresented = $0 }
  }
}

private struct SheetTestHost: View {
  let box: TestSheetBox
  let conditional: Bool

  var body: some View {
    Group {
      if conditional && (!box.isModifierMounted || box.item == nil) {
        Color.clear
      } else {
        ZStack(alignment: .topLeading) {
          Color.clear
          Text("Background")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { box.backgroundFrame = $0 }
        }
        .fcModal(item: Binding(
          get: { box.item },
          set: { box.item = $0 }
        )) { _ in
          SheetTestContent(box: box)
        }
        .onDisappear { box.modifierDisappearCount += 1 }
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
      .onDisappear { box.sheetDisappearCount += 1 }
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
