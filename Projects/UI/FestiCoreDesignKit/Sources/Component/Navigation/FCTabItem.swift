//
//  FCTabItem.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// `FCTab` 안의 한 칸. 선택되면 라벨 아래 밑줄을 그린다.
public struct FCTabItem: View {
  private var label: String
  private var isSelected: Bool

  public init(_ label: String, isSelected: Bool) {
    self.label = label
    self.isSelected = isSelected
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      Text(label)
        .festiCoreFont(isSelected ? .baseCalloutBold : .baseCalloutMedium)
        .foregroundStyle(
          isSelected
            ? FestiCoreSemanticColor.labelNormal.color
            : FestiCoreSemanticColor.labelAssistive.color
        )
        .lineLimit(1)
      UnevenRoundedRectangle(
        topLeadingRadius: Metric.indicatorRadius,
        topTrailingRadius: Metric.indicatorRadius
      )
      .fill(isSelected ? FestiCoreSemanticColor.labelNormal.color : .clear)
      .frame(height: Metric.indicatorHeight)
    }
    .padding(.top, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
  }
}

// MARK: - 체이닝 설정
public extension FCTabItem {
  /// `isSelected` 를 바꾼 사본을 돌려준다.
  func isSelected(_ isSelected: Bool) -> Self {
    var copy = self
    copy.isSelected = isSelected
    return copy
  }
}

private extension FCTabItem {
  enum Metric {
    static let indicatorHeight: CGFloat = 2
    static let indicatorRadius: CGFloat = 2
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCTabItem("선택됨", isSelected: true)
    FCTabItem("기본", isSelected: false)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
