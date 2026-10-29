//
//  FCBigButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 기수 보드 전용 큰 버튼. 그리드 칸을 꽉 채우며 selected는 지금 상태(Inverse)를 나타낸다.
public struct FCBigButton: View {
  private var label: String
  private var sub: String
  private var icon: ImageAsset
  private var action: () -> Void
  private(set) var isSelected = false

  public init(_ label: String, sub: String, icon: ImageAsset, action: @escaping () -> Void) {
    self.label = label
    self.sub = sub
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: icon)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
        Text(label)
          .festiCoreFont(.baseTitle1Bold)
          .frame(maxWidth: .infinity)
        Text(sub)
          .festiCoreFont(.baseFootnoteMedium)
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
          shape.stroke(FestiCoreSemanticColor.labelStrong.color, lineWidth: Metric.borderWidth)
        }
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: FestiCoreRadius.r24)
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
}

private extension FCBigButton {
  enum Metric {
    static let iconSize: CGFloat = 24
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCBigButton("존", sub: "리벳 앞 왼쪽", icon: .locationDot) {}
    FCBigButton("존", sub: "리벳 앞 왼쪽", icon: .locationDot) {}
      .isSelected(true)
  }
  .frame(height: 180)
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
