//
//  FCChecklistProgress.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 준비물 진행도. 막대 길이는 챙긴 비율이다.
public struct FCChecklistProgress: View {
  private var checked: Int
  private var total: Int

  public init(
    checked: Int,
    total: Int
  ) {
    self.checked = checked
    self.total = total
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Metric.spacing) {
      Text(title)
        // Figma Checklist Progress: Base/Headline/Bold(17/24)
        .festiCoreFont(.baseHeadlineBold)
        .festiCoreLineBox(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Capsule()
        .fill(FestiCoreSemanticColor.fillNormal.color)
        .frame(height: Metric.trackHeight)
        .overlay(alignment: .leading) {
          GeometryReader { proxy in
            Capsule()
              .fill(FestiCoreSemanticColor.labelNormal.color)
              .frame(width: proxy.size.width * ratio)
          }
        }
        .accessibilityHidden(true)
    }
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    .accessibilityElement(children: .combine)
  }

}

private extension FCChecklistProgress {
  /// Figma S12 H: 모두 챙기면 "준비 끝!" 문구로 바꾼다.
  var title: String {
    if total > 0 && checked >= total {
      return "\(total)개 모두 챙겼어요 · 준비 끝!"
    }
    return "\(total)개 중 \(checked)개 챙겼어요"
  }

  var ratio: CGFloat {
    guard total > 0 else { return 0 }
    return CGFloat(min(max(checked, 0), total)) / CGFloat(total)
  }
}

private extension FCChecklistProgress {
  enum Metric {
    static let spacing: CGFloat = 10
    static let trackHeight: CGFloat = 6
  }
}

#Preview {
  FCChecklistProgress(
    checked: 3,
    total: 7
  )
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
