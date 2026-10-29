//
//  FestiCoreSortButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 목록 정렬 기준 버튼. 칩과 목록 사이 오른쪽에 두고 누르면 `FestiCoreSortMenu`를 띄운다.
public struct FestiCoreSortButton: View {
  private var label: String
  private var action: () -> Void

  public init(_ label: String, action: @escaping () -> Void) {
    self.label = label
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        Image(asset: .filter16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        Text(label)
          .festiCoreFont(.baseFootnoteMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .lineLimit(1)
        // Figma는 chevron-right를 90도 돌린 인스턴스를 쓴다.
        Image(asset: .chevronRight16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .rotationEffect(.degrees(90))
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .padding(.vertical, FestiCoreSpacing.paddingP4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private extension FestiCoreSortButton {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  FestiCoreSortButton("활동 중 순") {}
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
