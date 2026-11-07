//
//  FestivalFlagDetailSkeletonView.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 깃발 상세를 불러오는 동안 히어로·지금 카드·오늘 계획 자리를 그대로 보인다.
struct FestivalFlagDetailSkeletonView: View {
  var body: some View {
    VStack(
      alignment: .leading,
      spacing: .zero
    ) {
      FCSkeletonView(.rect)
        .frame(height: Metric.heroHeight)

      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP24
      ) {
        FCSkeletonView(.round())
          .frame(height: Metric.nowCardHeight)

        FCSkeletonView(.round())
          .frame(height: Metric.planListHeight)
      }
      .padding(
        .top,
        FestiCoreSpacing.paddingP20
      )
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )

      Spacer(minLength: .zero)
    }
    .accessibilityIdentifier(FestivalAccessibilityID.flagDetailSkeleton)
  }
}

private extension FestivalFlagDetailSkeletonView {
  /// Figma S05 실측 높이
  enum Metric {
    static let heroHeight: CGFloat = 360
    static let nowCardHeight: CGFloat = 106
    static let planListHeight: CGFloat = 286
  }
}

#Preview {
  FestivalFlagDetailSkeletonView()
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .preferredColorScheme(.dark)
}
