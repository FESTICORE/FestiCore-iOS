//
//  BearerBoardSkeletonView.swift
//  Bearer
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 기수 보드 상태를 읽는 동안 머리글과 큰 버튼 자리를 보여 준다.
struct BearerBoardSkeletonView: View {
  var body: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      FCSkeletonView(.round())
        .frame(
          width: Metric.titleWidth,
          height: Metric.titleHeight
        )
      FCSkeletonView(.round())
        .frame(
          width: Metric.summaryWidth,
          height: Metric.summaryHeight
        )
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r24))
        .frame(maxHeight: .infinity)
    }
    .padding(FestiCoreSpacing.paddingP16)
    .accessibilityLabel("기수 보드를 불러오는 중")
  }
}

private extension BearerBoardSkeletonView {
  enum Metric {
    static let titleWidth: CGFloat = 160
    static let titleHeight: CGFloat = 32
    static let summaryWidth: CGFloat = 240
    static let summaryHeight: CGFloat = 20
  }
}

#Preview {
  BearerBoardSkeletonView()
    .background(FestiCoreSemanticColor.staticBlack.color)
}
