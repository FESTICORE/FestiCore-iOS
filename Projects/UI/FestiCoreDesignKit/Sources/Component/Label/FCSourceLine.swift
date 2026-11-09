//
//  FCSourceLine.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 정보 출처와 확인 시각 한 줄.
public struct FCSourceLine: View {
  private var source: String
  private var isInset = true

  public init(_ source: String) {
    self.source = source
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Image(asset: .circleCheck16)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .accessibilityHidden(true)
      Text(source)
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(
      .vertical,
      isInset ? FestiCoreSpacing.paddingP12 : .zero
    )
    .padding(
      .horizontal,
      isInset ? FestiCoreSpacing.paddingP16 : .zero
    )
    // Figma Source Line 띠: Fill/Normal
    .background(isInset ? FestiCoreSemanticColor.fillNormal.color : .clear)
  }
}

public extension FCSourceLine {
  /// 카드처럼 부모가 여백과 배경을 가진 곳에서는 false로 두어 띠와 안쪽 여백 없이 아이콘과 글자만 그린다(한 줄이면 높이 16).
  func inset(_ isInset: Bool) -> Self {
    var copy = self
    copy.isInset = isInset
    return copy
  }
}

private extension FCSourceLine {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  FCSourceLine("출처: 주최측 공지 · 확인 10/16 14:00")
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
