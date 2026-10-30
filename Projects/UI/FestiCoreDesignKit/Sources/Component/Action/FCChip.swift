//
//  FCChip.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 필터·선택 칩. selected는 Inverse(라이트 검정, 다크 흰색)로 표시한다.
public struct FCChip: View {
  private var label: String
  private var action: () -> Void
  private(set) var isSelected = false

  public init(
    _ label: String,
    action: @escaping () -> Void
  ) {
    self.label = label
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(label)
        .festiCoreFont(.baseFootnoteMedium)
        .foregroundStyle(isSelected ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelNeutral.color)
        .lineLimit(1)
        .padding(.horizontal, FestiCoreSpacing.paddingP12)
        .frame(height: Metric.height)
        .background(
          isSelected ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.backgroundElevated.color,
          in: Capsule()
        )
        .overlay {
          if !isSelected {
            Capsule().stroke(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth)
          }
        }
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - 체이닝 설정

public extension FCChip {
  /// 선택 상태를 바꾼 사본을 돌려준다.
  func isSelected(_ isSelected: Bool) -> Self {
    var copy = self
    copy.isSelected = isSelected
    return copy
  }
}

private extension FCChip {
  enum Metric {
    static let height: CGFloat = 32
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP12) {
    FCChip("전체") {}
      .isSelected(true)
    FCChip("내 일정") {}
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
