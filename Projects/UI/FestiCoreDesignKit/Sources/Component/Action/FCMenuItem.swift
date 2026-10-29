//
//  FCMenuItem.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 드롭다운 한 줄. 선택된 항목은 굵게 표시하고 체크를 붙인다.
public struct FCMenuItem: View {
  private var label: String
  private(set) var isSelected = false

  public init(_ label: String) {
    self.label = label
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Text(label)
        .festiCoreFont(isSelected ? .baseCalloutBold : .baseCalloutRegular)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      if isSelected {
        Image(asset: .check)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .accessibilityHidden(true)
      }
    }
    .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - 체이닝 설정

public extension FCMenuItem {
  /// 선택 상태를 바꾼 사본을 돌려준다.
  func isSelected(_ isSelected: Bool) -> Self {
    var copy = self
    copy.isSelected = isSelected
    return copy
  }
}

private extension FCMenuItem {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP8) {
    FCMenuItem("활동 중 순")
      .isSelected(true)
    FCMenuItem("활동 중 순")
  }
  .frame(width: 200)
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
