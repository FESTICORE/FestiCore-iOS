//
//  FCBackPill.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 모드 전환·뒤로 가기 알약 버튼. 기수 보드 왼쪽 위 "관객 화면으로"에 쓴다.
public struct FCBackPill: View {
  private var label: String
  private var action: () -> Void

  public init(_ label: String, action: @escaping () -> Void) {
    self.label = label
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        Image(asset: .chevronLeft16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .accessibilityHidden(true)
        Text(label)
          .festiCoreFont(.baseFootnoteMedium)
          .lineLimit(1)
      }
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .padding(.vertical, FestiCoreSpacing.paddingP8)
      .padding(.leading, Metric.leadingPadding)
      .padding(.trailing, Metric.trailingPadding)
      .background(FestiCoreSemanticColor.backgroundElevated.color, in: Capsule())
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

private extension FCBackPill {
  enum Metric {
    static let iconSize: CGFloat = 16
    static let leadingPadding: CGFloat = 10
    static let trailingPadding: CGFloat = 14
  }
}

#Preview {
  FCBackPill("관객 화면으로") {}
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
