//
//  FestivalZoneMapSkeletonView.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 받아 둔 팩에서 존 지도를 읽는 동안 무대 머리글과 존 영역 자리를 보여 준다.
struct FestivalZoneMapSkeletonView: View {
  var body: some View {
    VStack(spacing: FestiCoreSpacing.marginM12) {
      HStack(spacing: FestiCoreSpacing.marginM12) {
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r8))
          .frame(height: Metric.headerHeight)
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r8))
          .frame(height: Metric.headerHeight)
      }
      ForEach(
        Metric.rowHeights,
        id: \.self
      ) { height in
        HStack(spacing: FestiCoreSpacing.marginM12) {
          FCSkeletonView(.round(cornerRadius: Metric.areaRadius))
          FCSkeletonView(.round(cornerRadius: Metric.areaRadius))
        }
        .frame(height: height)
      }
      Spacer(minLength: .zero)
    }
    .padding(FestiCoreSpacing.paddingP16)
    .accessibilityLabel("존 지도를 불러오는 중")
  }
}

private extension FestivalZoneMapSkeletonView {
  enum Metric {
    static let headerHeight: CGFloat = 26
    static let areaRadius: CGFloat = 10
    static let rowHeights: [CGFloat] = [98, 94, 58, 160]
  }
}

#Preview {
  FestivalZoneMapSkeletonView()
}
