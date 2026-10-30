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
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.fillNormal.color)
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
