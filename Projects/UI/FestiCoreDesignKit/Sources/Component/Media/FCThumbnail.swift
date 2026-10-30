//
//  FCThumbnail.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 작은 썸네일. 이미지가 없으면 빈 상태 아이콘을 보이며 아이콘과 크기는 바꿀 수 있다.
public struct FCThumbnail: View {
  private var image: Image?
  private(set) var placeholderIcon: ImageAsset = .flag20
  private(set) var side: CGFloat = Metric.size
  private(set) var cornerRadius: CGFloat?

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
          .frame(width: iconSize, height: iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(FestiCoreSemanticColor.fillStrong.color)
      }
    }
    .frame(width: side, height: side)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? FestiCoreRadius.r12 * scale))
    .accessibilityHidden(true)
  }

  private var scale: CGFloat {
    side / Metric.size
  }

  private var iconSize: CGFloat {
    // 56 기준 아이콘 20을 유지하되, 작은 썸네일에서는 Figma처럼 비율대로 줄인다.
    cornerRadius == nil ? Metric.iconSize * scale : Metric.iconSize
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

  /// 한 변 길이를 바꾼 사본을 돌려준다. 반경을 지정하지 않으면 56 기준 반경 12와 아이콘 20을 비율대로 줄인다.
  func size(
    _ side: CGFloat,
    cornerRadius: CGFloat? = nil
  ) -> Self {
    var copy = self
    copy.side = side
    copy.cornerRadius = cornerRadius
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
    FCThumbnail(nil)
      .placeholderIcon(.music20)
      .size(48)
    FCThumbnail(nil)
      .size(40, cornerRadius: FestiCoreRadius.r12)
    FCThumbnail(Image(systemName: "photo"))
  }
  .padding(FestiCoreSpacing.paddingP12)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
