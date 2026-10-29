//
//  FCNowLine.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 현재 시각 선. Inverse 색을 쓴다.
public struct FCNowLine: View {
  private var time: String

  public init(time: String) {
    self.time = time
  }

  public var body: some View {
    ZStack(alignment: .leading) {
      FestiCoreSemanticColor.inverseBackground.color
        .frame(height: Metric.lineHeight)
      Text(time)
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.inverseLabel.color)
        .padding(.vertical, FestiCoreSpacing.marginM2)
        .padding(.horizontal, FestiCoreSpacing.marginM6)
        .background(
          FestiCoreSemanticColor.inverseBackground.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
        )
    }
    .frame(height: Metric.height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("현재 시각 \(time)")
  }
}

// MARK: - 체이닝 설정
public extension FCNowLine {
  /// `time` 을 바꾼 사본을 돌려준다.
  func time(_ time: String) -> Self {
    var copy = self
    copy.time = time
    return copy
  }
}

private extension FCNowLine {
  enum Metric {
    static let height: CGFloat = 20
    static let lineHeight: CGFloat = 2
  }
}

#Preview {
  FCNowLine(time: "18:30")
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
