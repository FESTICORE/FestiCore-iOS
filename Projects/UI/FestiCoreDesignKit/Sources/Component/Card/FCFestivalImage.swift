//
//  FCFestivalImage.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 페스티벌 대표 이미지. 이미지가 없으면 빈 상태 아이콘을 보인다.
/// 원격 이미지는 SharedUI의 `FCRemoteImage`를 `FCFestivalCard`의 media로 넘긴다.
public struct FCFestivalImage: View {
  private var image: Image?

  public init(_ image: Image?) {
    self.image = image
  }

  public var body: some View {
    Group {
      if let image {
        image
          .resizable()
          .scaledToFill()
      } else {
        Image(asset: .music24)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(FestiCoreSemanticColor.fillStrong.color)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: Metric.height)
    .clipped()
    .accessibilityHidden(true)
  }
}

private extension FCFestivalImage {
  enum Metric {
    static let height: CGFloat = 140
    static let iconSize: CGFloat = 36
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCFestivalImage(nil)
    FCFestivalImage(Image(systemName: "photo"))
  }
  .padding(FestiCoreSpacing.paddingP16)
}
