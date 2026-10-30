//
//  FCThumbnail.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 작은 썸네일. 이미지가 없으면 빈 상태 아이콘을 보이며 아이콘은 바꿀 수 있다.
public struct FCThumbnail: View {
  private var image: Image?
  private(set) var placeholderIcon: ImageAsset = .flag20

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
        Image(asset: placeholderIcon)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(FestiCoreSemanticColor.fillStrong.color)
      }
    }
    .frame(width: Metric.size, height: Metric.size)
    .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    .accessibilityHidden(true)
  }
}

// MARK: - 체이닝 설정

public extension FCThumbnail {
  /// 빈 상태 아이콘을 바꾼 사본을 돌려준다.
  func placeholderIcon(_ icon: ImageAsset) -> Self {
    var copy = self
    copy.placeholderIcon = icon
    return copy
  }
}

private extension FCThumbnail {
  enum Metric {
    static let size: CGFloat = 56
    static let iconSize: CGFloat = 20
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCThumbnail(nil)
    FCThumbnail(Image(systemName: "photo"))
  }
  .padding(FestiCoreSpacing.paddingP12)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
