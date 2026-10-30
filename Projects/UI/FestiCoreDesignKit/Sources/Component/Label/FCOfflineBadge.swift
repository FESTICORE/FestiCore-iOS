//
//  FCOfflineBadge.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 오프라인·N분 전 정보 안내 띠. Top Bar 바로 아래 화면 너비로 두고 바깥 여백을 더하지 않는다.
public struct FCOfflineBadge: View {
  private var message: String

  public init(_ message: String) {
    self.message = message
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Image(asset: .circleInfo16)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .accessibilityHidden(true)
      Text(message)
        .festiCoreFont(.baseFootnoteMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundStyle(FestiCoreSemanticColor.statusInfo.color)
    .padding(.vertical, FestiCoreSpacing.paddingP8)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.accentBackgroundBlue.color)
  }
}

private extension FCOfflineBadge {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  FCOfflineBadge("오프라인 · 3분 전 정보")
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
