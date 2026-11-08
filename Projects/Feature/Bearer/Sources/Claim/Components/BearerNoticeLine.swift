//
//  BearerNoticeLine.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 입력 칸 아래 안내 한 줄. 경고는 빨간 삼각형, 안내는 회색 정보 아이콘이다.
struct BearerNoticeLine: View {
  let text: String
  let isWarning: Bool

  var body: some View {
    HStack(spacing: FestiCoreSpacing.marginM6) {
      Image(asset: isWarning ? .triangleExclamation16 : .circleInfo16)
        .resizable()
        .frame(
          width: Metric.iconSize,
          height: Metric.iconSize
        )
        .accessibilityHidden(true)
      Text(text)
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
    }
    .foregroundStyle(
      isWarning ? FestiCoreSemanticColor.statusNegative.color : FestiCoreSemanticColor.labelAssistive.color
    )
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Figma Inline Message: 아이콘 16, 글자 13/18
  private enum Metric {
    static let iconSize: CGFloat = 16
  }
}
