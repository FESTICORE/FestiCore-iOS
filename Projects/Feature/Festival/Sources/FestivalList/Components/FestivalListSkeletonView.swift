import FestiCoreDesignKit
import SwiftUI

struct FestivalListSkeletonView: View {
  var body: some View {
    LazyVStack(spacing: FestiCoreSpacing.paddingP16) {
      ForEach(0..<3, id: \.self) { _ in
        card
      }
    }
    .accessibilityIdentifier(FestivalAccessibilityID.listSkeleton)
  }
}

private extension FestivalListSkeletonView {
  /// Figma Festival Card와 같은 순서: 포스터, 제목·태그, 장소·날짜, 팩 안내, 예매처 줄
  var card: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    return VStack(spacing: .zero) {
      FCSkeletonView(.rect)
        .frame(height: Metric.mediaHeight)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          FCSkeletonView(.round())
            .frame(width: Metric.titleWidth, height: Metric.titleHeight)
          Spacer(minLength: .zero)
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4))
            .frame(width: Metric.tagWidth, height: Metric.tagHeight)
        }
        FCSkeletonView(.round())
          .frame(width: Metric.metaWidth, height: Metric.metaHeight)
        FCSkeletonView(.round())
          .frame(width: Metric.helperWidth, height: Metric.helperHeight)
      }
      .padding(FestiCoreSpacing.paddingP12)
      .frame(maxWidth: .infinity, alignment: .leading)
      FCSkeletonView(.round())
        .frame(width: Metric.linkWidth, height: Metric.linkHeight)
        .padding(FestiCoreSpacing.paddingP12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .clipShape(shape)
    .overlay { shape.strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth) }
  }

  enum Metric {
    static let mediaHeight: CGFloat = 140
    static let titleWidth: CGFloat = 200
    static let titleHeight: CGFloat = 24
    static let tagWidth: CGFloat = 40
    static let tagHeight: CGFloat = 22
    static let metaWidth: CGFloat = 240
    static let metaHeight: CGFloat = 18
    static let helperWidth: CGFloat = 260
    static let helperHeight: CGFloat = 16
    static let linkWidth: CGFloat = 84
    static let linkHeight: CGFloat = 18
    static let borderWidth: CGFloat = 1
  }
}
