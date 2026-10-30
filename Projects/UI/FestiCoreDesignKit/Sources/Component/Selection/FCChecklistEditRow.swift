//
//  FCChecklistEditRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 준비물 편집 한 줄. 내 항목은 삭제할 수 있고 운영팀 필수 항목은 삭제할 수 없다.
public struct FCChecklistEditRow: View {
  private var label: String
  private(set) var onDelete: (() -> Void)?

  public init(_ label: String) {
    self.label = label
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Text(label)
        .festiCoreFont(.baseCalloutRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let onDelete {
        Button(action: onDelete) {
          Image(asset: .trashCan20)
            .resizable()
            .frame(width: Metric.iconSize, height: Metric.iconSize)
            .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
            .frame(width: Metric.deleteSize, height: Metric.deleteSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) 삭제")
      } else {
        FCTag("필수 · 삭제 불가")
      }
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(height: Metric.height)
  }
}

// MARK: - 체이닝 설정

public extension FCChecklistEditRow {
  /// 삭제 동작을 바꾼 사본을 돌려준다. `nil`이면 운영팀 필수 항목으로 보고 삭제 버튼 대신 태그를 표시한다.
  func onDelete(_ action: (() -> Void)?) -> Self {
    var copy = self
    copy.onDelete = action
    return copy
  }
}

private extension FCChecklistEditRow {
  enum Metric {
    static let height: CGFloat = 56
    static let deleteSize: CGFloat = 32
    static let iconSize: CGFloat = 20
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP8) {
    FCChecklistEditRow("귀마개")
      .onDelete {}
    FCChecklistEditRow("귀마개")
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
