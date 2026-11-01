import FestiCoreDesignKit
import SwiftUI

/// 라이브 보드의 공연 카드와 무대 목록을 불러오는 동안 보여 준다.
struct FestivalLiveBoardSkeletonView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 144)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
        FCSkeletonView(.round())
          .frame(width: 120, height: 22)
        ForEach(0..<2, id: \.self) { _ in
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
            .frame(height: 88)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("라이브 보드를 불러오는 중")
    .accessibilityIdentifier("festivalLiveBoardSkeleton")
  }
}
