//
//  FCBadge.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 안 읽은 알림 개수. 10 이상은 9+로 표시하고 0 이하는 그리지 않는다.
public struct FCBadge: View {
  private var count: Int

  public init(count: Int) {
    self.count = count
  }

  public var body: some View {
    if count > 0 {
      Text(count > Metric.maxCount ? "\(Metric.maxCount)+" : "\(count)")
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
        .monospacedDigit()
        .padding(.horizontal, FestiCoreSpacing.paddingP4)
        .frame(minWidth: Metric.size, minHeight: Metric.size)
        .background(FestiCoreSemanticColor.statusNegative.color, in: Capsule())
        .accessibilityLabel("안 읽은 알림 \(count)개")
    }
  }
}

private extension FCBadge {
  enum Metric {
    static let size: CGFloat = 16
    static let maxCount = 9
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP12) {
    FCBadge(count: 3)
    FCBadge(count: 12)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
