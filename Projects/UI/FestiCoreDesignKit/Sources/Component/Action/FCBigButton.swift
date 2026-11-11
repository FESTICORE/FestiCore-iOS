//
//  FCBigButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 기수 보드 큰 버튼. 그리드 칸을 꽉 채우며 selected는 지금 상태(Inverse)를 나타낸다.
/// `.size(.small)`은 Figma Big Button의 80×64 변형(S07 크루 내 상태 버튼)이다.
public struct FCBigButton: View {
  public enum Size: Sendable {
    case regular
    case small
  }

  private var label: String
  private var sub: String
  private var icon: ImageAsset
  private var action: () -> Void
  private(set) var isSelected = false
  private(set) var size = Size.regular

  public init(
    _ label: String,
    sub: String,
    icon: ImageAsset,
    action: @escaping () -> Void
  ) {
    self.label = label
    self.sub = sub
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    switch size {
    case .regular:
      regularButton
    case .small:
      smallButton
    }
  }

}

private extension FCBigButton {
  var regularButton: some View {
    return Button(action: action) {
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: icon)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
        Text(label)
          .festiCoreFont(.baseTitle1Bold)
          .festiCoreLineBox(.baseTitle1Bold)
          .frame(maxWidth: .infinity)
        Text(sub)
          .festiCoreFont(.baseFootnoteMedium)
          .festiCoreLineBox(.baseFootnoteMedium)
          // Figma S09: 선택 전 보조 문구는 labelNeutral(#C9C9CF)이다.
          .foregroundStyle(isSelected ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity)
      }
      .multilineTextAlignment(.center)
      .foregroundStyle(isSelected ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelStrong.color)
      .padding(FestiCoreSpacing.paddingP16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        isSelected ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.backgroundElevated.color,
        in: shape
      )
      .overlay {
        if !isSelected {
          // Figma S09 Big Button 테두리는 lineNormal(#2A2A30)이다.
          shape.stroke(
            FestiCoreSemanticColor.lineNormal.color,
            lineWidth: Metric.borderWidth
          )
        }
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  /// Figma Big Button small(80×64): 위아래 12·좌우 8, 간격 6, 아이콘 20, Footnote/Bold, r12, 바탕 Fill/Normal
  var smallButton: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    return Button(action: action) {
      VStack(spacing: FestiCoreSpacing.marginM6) {
        Image(asset: icon)
          .resizable()
          .scaledToFit()
          .frame(
            width: Metric.smallIconSize,
            height: Metric.smallIconSize
          )
          .accessibilityHidden(true)
        Text(label)
          .festiCoreFont(.baseFootnoteBold)
          .festiCoreLineBox(.baseFootnoteBold)
          .lineLimit(1)
      }
      .foregroundStyle(isSelected ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelNormal.color)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP8
      )
      .padding(
        .vertical,
        FestiCoreSpacing.paddingP12
      )
      .frame(
        maxWidth: .infinity,
        minHeight: Metric.smallHeight
      )
      .background(
        isSelected ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.fillNormal.color,
        in: shape
      )
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  var shape: RoundedRectangle {
    return RoundedRectangle(cornerRadius: FestiCoreRadius.r24)
  }
}

// MARK: - 체이닝 설정

public extension FCBigButton {
  /// 선택 상태를 바꾼 사본을 돌려준다.
  func isSelected(_ isSelected: Bool) -> Self {
    var copy = self
    copy.isSelected = isSelected
    return copy
  }

  /// 크기 변형을 바꾼 사본을 돌려준다. small은 보조 문구를 그리지 않는다.
  func size(_ size: Size) -> Self {
    var copy = self
    copy.size = size
    return copy
  }
}

private extension FCBigButton {
  enum Metric {
    static let iconSize: CGFloat = 24
    static let borderWidth: CGFloat = 1
    static let smallIconSize: CGFloat = 20
    static let smallHeight: CGFloat = 64
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCBigButton(
      "존",
      sub: "리벳 앞 왼쪽",
      icon: .locationDot
    ) {}
    FCBigButton(
      "존",
      sub: "리벳 앞 왼쪽",
      icon: .locationDot
    ) {}
      .isSelected(true)
  }
  .frame(height: 180)
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
