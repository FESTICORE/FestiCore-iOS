//
//  FCButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 기본 버튼. primary는 화면의 핵심 행동 1개, inverse는 카드 안·반복 버튼, secondary·ghost는 보조, accent는 브랜드 포인트에 쓴다.
public struct FCButton: View {
  public enum Style: Sendable {
    case primary
    case secondary
    case ghost
    case accent
    case inverse
  }

  public enum Size: Sendable {
    /// 높이 52
    case large
    /// 높이 40
    case medium
  }

  private var title: String
  private var action: () -> Void
  private(set) var style: Style = .primary
  private(set) var size: Size = .large
  private(set) var isEnabled = true

  public init(
    _ title: String,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(title)
        .festiCoreFont(size == .large ? .baseCalloutBold : .baseSubheadlineBold)
        .foregroundStyle(foregroundColor.color)
        .lineLimit(1)
        .padding(.horizontal, size == .large ? FestiCoreSpacing.paddingP20 : FestiCoreSpacing.paddingP16)
        .frame(height: size == .large ? Metric.largeHeight : Metric.mediumHeight)
        .background(backgroundColor, in: shape)
        .overlay {
          if style == .secondary {
            shape.stroke(FestiCoreSemanticColor.lineStrong.color, lineWidth: Metric.borderWidth)
          }
        }
        .contentShape(shape)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    // Foundation state.disabled는 요소 전체에 30% opacity를 적용한다.
    .opacity(isEnabled ? 1 : FestiCoreState.disabledOpacity)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: size == .large ? FestiCoreRadius.r12 : FestiCoreRadius.r8)
  }

  private var backgroundColor: Color {
    switch style {
    case .primary: return FestiCoreSemanticColor.primaryNormal.color
    case .secondary: return FestiCoreSemanticColor.backgroundElevated.color
    case .ghost: return .clear
    case .accent: return FestiCoreSemanticColor.accentPointLime.color
    case .inverse: return FestiCoreSemanticColor.inverseBackground.color
    }
  }

  private var foregroundColor: FestiCoreSemanticColor {
    switch style {
    case .primary: return .primaryOnPrimary
    case .secondary, .ghost: return .labelNormal
    case .accent: return .staticInk
    case .inverse: return .inverseLabel
    }
  }
}

// MARK: - 체이닝 설정

public extension FCButton {
  /// 버튼 스타일을 바꾼 사본을 돌려준다.
  func style(_ style: Style) -> Self {
    var copy = self
    copy.style = style
    return copy
  }

  /// 버튼 크기를 바꾼 사본을 돌려준다.
  func size(_ size: Size) -> Self {
    var copy = self
    copy.size = size
    return copy
  }

  /// 활성 여부를 바꾼 사본을 돌려준다.
  func isEnabled(_ isEnabled: Bool) -> Self {
    var copy = self
    copy.isEnabled = isEnabled
    return copy
  }
}

private extension FCButton {
  enum Metric {
    static let largeHeight: CGFloat = 52
    static let mediumHeight: CGFloat = 40
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP12) {
    ForEach([FCButton.Style.primary, .secondary, .ghost, .accent, .inverse], id: \.self) { style in
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FCButton("버튼") {}
          .style(style)
        FCButton("버튼") {}
          .style(style)
          .size(.medium)
        FCButton("버튼") {}
          .style(style)
          .isEnabled(false)
      }
    }
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
