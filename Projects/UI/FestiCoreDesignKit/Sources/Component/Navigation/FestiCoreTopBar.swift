//
//  FestiCoreTopBar.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 화면 맨 위 바. 바탕은 글래스(blur)다.
public struct FestiCoreTopBar: View {
  public enum Style {
    /// 홈
    case logo
    /// 하위 화면
    case back
    /// 탭 첫 화면
    case large
    /// 검색
    case search(text: Binding<String>)
    /// 기수용 홈
    case logoBearer
    /// 사진 위로 스크롤했을 때(흰 글자)
    case backOnImage
  }

  struct TrailingAction {
    let icon: ImageAsset
    let accessibilityLabel: String
    let action: () -> Void
  }

  private var style: Style
  private var title: String
  private(set) var backAction: (() -> Void)?
  private(set) var trailing: TrailingAction?
  private(set) var showsBadge = false
  private(set) var bearerTitle = "기수"
  private(set) var bearerAction: (() -> Void)?
  private(set) var cancelAction: (() -> Void)?
  private(set) var searchPlaceholder = ""

  public init(_ style: Style, title: String = "") {
    self.style = style
    self.title = title
  }

  public var body: some View {
    content
      .frame(height: height)
      .frame(maxWidth: .infinity)
      .background { background.ignoresSafeArea(edges: .top) }
  }

  @ViewBuilder
  private var content: some View {
    switch style {
    case .logo:
      HStack(spacing: .zero) {
        logo
        Spacer(minLength: .zero)
        trailingButton
      }
      .padding(.leading, FestiCoreSpacing.paddingP20)
      .padding(.trailing, FestiCoreSpacing.paddingP8)

    case .back, .backOnImage:
      HStack(spacing: FestiCoreSpacing.paddingP16) {
        backButton
        Text(title)
          .festiCoreTextStyle(.baseBodyBold)
          .foregroundStyle(foregroundColor.color)
          .lineLimit(1)
          .frame(maxWidth: .infinity)
          .accessibilityAddTraits(.isHeader)
        trailingButton
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP8)

    case .large:
      HStack(spacing: FestiCoreSpacing.paddingP16) {
        Text(title)
          .festiCoreTextStyle(.baseTitle1Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityAddTraits(.isHeader)
        trailingButton
      }
      .padding(.leading, FestiCoreSpacing.paddingP20)
      .padding(.trailing, FestiCoreSpacing.paddingP8)

    case let .search(text):
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        SearchField(text: text, placeholder: searchPlaceholder)
        if let cancelAction {
          Button(action: cancelAction) {
            Text("취소")
              .festiCoreTextStyle(.baseCalloutMedium)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)

    case .logoBearer:
      HStack(spacing: .zero) {
        logo
        Spacer(minLength: .zero)
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          bearerButton
          trailingButton
        }
      }
      .padding(.leading, FestiCoreSpacing.paddingP20)
      .padding(.trailing, FestiCoreSpacing.paddingP8)
    }
  }

  private var logo: some View {
    Image(asset: .logo)
      .resizable()
      .scaledToFit()
      .frame(width: Metric.logoWidth, height: Metric.logoHeight)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .accessibilityLabel("FESTICORE")
  }

  @ViewBuilder
  private var backButton: some View {
    if let backAction {
      IconButton(icon: .chevronLeft, iconSize: Metric.backIconSize, color: foregroundColor, action: backAction)
        .accessibilityLabel("뒤로")
    } else if keepsTitleCentered {
      Color.clear.frame(width: Metric.touchSize, height: Metric.touchSize)
    }
  }

  @ViewBuilder
  private var trailingButton: some View {
    if showsTrailing, let trailing {
      IconButton(icon: trailing.icon, iconSize: Metric.iconSize, color: foregroundColor, action: trailing.action)
        .overlay(alignment: .topTrailing) {
          if showsBadge {
            Circle()
              .fill(FestiCoreSemanticColor.statusNegative.color)
              .frame(width: Metric.badgeSize, height: Metric.badgeSize)
              .offset(x: -Metric.badgeInset, y: Metric.badgeInset)
              .accessibilityHidden(true)
          }
        }
        .accessibilityLabel(trailing.accessibilityLabel)
        .accessibilityValue(showsBadge ? "새 소식 있음" : "")
    } else if keepsTitleCentered {
      Color.clear.frame(width: Metric.touchSize, height: Metric.touchSize)
    }
  }

  @ViewBuilder
  private var bearerButton: some View {
    if let bearerAction {
      Button(action: bearerAction) {
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          Image(asset: .flag16)
            .resizable()
            .frame(width: Metric.smallIconSize, height: Metric.smallIconSize)
          Text(bearerTitle)
            .festiCoreTextStyle(.baseFootnoteBold)
        }
        .foregroundStyle(FestiCoreSemanticColor.accentForegroundPurple.color)
        .padding(.horizontal, FestiCoreSpacing.paddingP12)
        .frame(height: Metric.bearerHeight)
        .background(FestiCoreSemanticColor.accentBackgroundPurple.color, in: Capsule())
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var background: some View {
    if case .backOnImage = style {
      Rectangle()
        .fill(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .overlay(FestiCoreSemanticColor.staticalphaBlack20.color)
    } else {
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(FestiCoreSemanticColor.materialGlass.color)
    }
  }

  /// back 계열은 제목을 가운데에 두려고 빈 버튼 자리도 유지한다.
  private var keepsTitleCentered: Bool {
    switch style {
    case .back, .backOnImage: return true
    default: return false
    }
  }

  private var foregroundColor: FestiCoreSemanticColor {
    if case .backOnImage = style { return .staticWhite }
    return .labelNormal
  }

  var height: CGFloat {
    switch style {
    case .large, .search: return Metric.largeHeight
    default: return Metric.height
    }
  }

  var defaultTrailingIcon: (asset: ImageAsset, label: String) {
    switch style {
    case .logo, .logoBearer: return (.bell, "알림")
    default: return (.magnifyingGlass, "검색")
    }
  }

  /// trailing 버튼은 action을 지정한 경우에만 보이고, search 스타일에는 없다.
  var showsTrailing: Bool {
    if case .search = style { return false }
    return trailing != nil
  }
}

// MARK: - 체이닝 설정
//
// 값 타입 사본을 돌려주므로 호출 순서에 영향받지 않는다.
public extension FestiCoreTopBar {
  /// 뒤로 버튼 action을 지정한 사본을 돌려준다. 지정하지 않으면 뒤로 버튼을 그리지 않는다.
  func onBack(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.backAction = action
    return copy
  }

  /// 스타일 기본 아이콘(logo 계열은 알림, back 계열은 검색)으로 trailing 버튼을 지정한 사본을 돌려준다.
  func trailingAction(_ action: @escaping () -> Void) -> Self {
    let icon = defaultTrailingIcon
    return trailingAction(icon: icon.asset, accessibilityLabel: icon.label, action: action)
  }

  /// trailing 버튼의 아이콘과 action을 지정한 사본을 돌려준다.
  func trailingAction(
    icon: ImageAsset,
    accessibilityLabel: String,
    action: @escaping () -> Void
  ) -> Self {
    var copy = self
    copy.trailing = TrailingAction(icon: icon, accessibilityLabel: accessibilityLabel, action: action)
    return copy
  }

  /// trailing 아이콘 우상단 점(Figma `Show Badge`)을 켠 사본을 돌려준다.
  func showsBadge(_ isShown: Bool) -> Self {
    var copy = self
    copy.showsBadge = isShown
    return copy
  }

  /// logoBearer 스타일의 기수 버튼을 지정한 사본을 돌려준다.
  func onBearer(title: String = "기수", _ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.bearerTitle = title
    copy.bearerAction = action
    return copy
  }

  /// search 스타일의 취소 버튼을 지정한 사본을 돌려준다.
  func onCancel(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.cancelAction = action
    return copy
  }

  /// `searchPlaceholder` 를 바꾼 사본을 돌려준다.
  func searchPlaceholder(_ placeholder: String) -> Self {
    var copy = self
    copy.searchPlaceholder = placeholder
    return copy
  }
}

private extension FestiCoreTopBar {
  enum Metric {
    static let height: CGFloat = 52
    static let largeHeight: CGFloat = 60
    static let touchSize: CGFloat = 44
    static let iconSize: CGFloat = 24
    static let backIconSize: CGFloat = 20
    static let smallIconSize: CGFloat = 16
    static let logoWidth: CGFloat = 108
    static let logoHeight: CGFloat = 24
    static let bearerHeight: CGFloat = 32
    static let searchHeight: CGFloat = 40
    static let badgeSize: CGFloat = 6
    static let badgeInset: CGFloat = 10
  }

  struct IconButton: View {
    let icon: ImageAsset
    let iconSize: CGFloat
    let color: FestiCoreSemanticColor
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Image(asset: icon)
          .resizable()
          .frame(width: iconSize, height: iconSize)
          .foregroundStyle(color.color)
          .frame(width: Metric.touchSize, height: Metric.touchSize)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: .magnifyingGlass16)
          .resizable()
          .frame(width: Metric.smallIconSize, height: Metric.smallIconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .accessibilityHidden(true)
        TextField(placeholder, text: $text)
          .festiCoreTextStyle(.baseCalloutRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .submitLabel(.search)
        if !text.isEmpty {
          Button {
            text = ""
          } label: {
            Image(asset: .circleXmark)
              .resizable()
              .frame(width: Metric.smallIconSize, height: Metric.smallIconSize)
              .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("검색어 지우기")
        }
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP12)
      .frame(height: Metric.searchHeight)
      .background(
        FestiCoreSemanticColor.fillNormal.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
      )
    }
  }
}
