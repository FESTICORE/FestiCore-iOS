import FestiCoreDesignKit
import SwiftUI

struct FestivalListSkeletonView: View {
  var body: some View {
    LazyVStack(spacing: FestiCoreSpacing.paddingP16) {
      ForEach(0..<3, id: \.self) { _ in
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
            .frame(height: 142)
          FCSkeletonView(.round())
            .frame(width: 220, height: 25)
          FCSkeletonView(.round())
            .frame(width: 170, height: 17)
          FCSkeletonView(.round())
            .frame(width: 120, height: 15)
        }
        .padding(.bottom, FestiCoreSpacing.paddingP16)
        .background(FestiCoreSemanticColor.backgroundElevated.color,
                    in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      }
    }
    .accessibilityIdentifier("festivalListSkeleton")
  }
}
