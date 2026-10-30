//
//  FCChecklistRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 준비물 체크리스트 한 줄. 줄 전체를 눌러 체크한다.
public struct FCChecklistRow: View {
  private var label: String
  private var isChecked: Bool
  private var action: () -> Void
  private(set) var isRequired = false

  public init(
    _ label: String,
    isChecked: Bool,
    action: @escaping () -> Void
  ) {
    self.label = label
    self.isChecked = isChecked
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FCCheckCircle(isChecked: isChecked)
          .iconSize(Metric.checkIconSize)
        Text(label)
          .festiCoreFont(.baseCalloutMedium)
          .foregroundStyle(isChecked ? FestiCoreSemanticColor.labelAssistive.color : FestiCoreSemanticColor.labelNormal.color)
          .frame(maxWidth: .infinity, alignment: .leading)
        if isRequired {
          FCTag("필수")
        }
      }
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .background(FestiCoreSemanticColor.backgroundElevated.color)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isChecked ? .isSelected : [])
  }
}

// MARK: - 체이닝 설정

public extension FCChecklistRow {
  /// 운영팀 필수 항목 여부를 바꾼 사본을 돌려준다.
  func isRequired(_ isRequired: Bool) -> Self {
    var copy = self
    copy.isRequired = isRequired
    return copy
  }
}

private extension FCChecklistRow {
  enum Metric {
    static let checkIconSize: CGFloat = 14
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP12) {
    FCChecklistRow(
      "보조배터리",
      isChecked: false
    ) {}
    FCChecklistRow(
      "보조배터리",
      isChecked: true
    ) {}
    FCChecklistRow(
      "티켓",
      isChecked: false
    ) {}
      .isRequired(true)
  }
  .padding(FestiCoreSpacing.paddingP12)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
