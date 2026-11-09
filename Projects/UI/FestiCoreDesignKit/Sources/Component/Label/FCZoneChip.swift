//
//  FCZoneChip.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 존 위치 칩. 누르면 존 지도로 이동한다.
public struct FCZoneChip: View {
  private var zone: String
  private var action: () -> Void

  public init(
    _ zone: String,
    action: @escaping () -> Void
  ) {
    self.zone = zone
    self.action = action
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: .locationDot16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .accessibilityHidden(true)
        Text(zone)
          .festiCoreFont(.baseCaption1Medium)
          .festiCoreLineBox(.baseCaption1Medium)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .lineLimit(1)
      }
      // Figma 칩(높이 26)은 안쪽 테두리 1pt를 배치에 포함한다.
      .padding(
        .vertical,
        FestiCoreSpacing.paddingP4 + Metric.borderWidth
      )
      // Figma Zone Chip은 테두리(1pt)가 자리를 차지해 좌우에도 1pt를 더한다(100×26).
      .padding(
        .leading,
        FestiCoreSpacing.marginM6 + Metric.borderWidth
      )
      .padding(
        .trailing,
        FestiCoreSpacing.paddingP8 + Metric.borderWidth
      )
      .background(FestiCoreSemanticColor.backgroundElevated.color, in: shape)
      .overlay { shape.strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth) }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
  }
}

private extension FCZoneChip {
  enum Metric {
    static let iconSize: CGFloat = 16
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  FCZoneChip("리벳 앞 왼쪽") {}
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
