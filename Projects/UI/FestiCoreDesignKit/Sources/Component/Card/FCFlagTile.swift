//
//  FCFlagTile.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 2열 그리드 타일.
public struct FCFlagTile: View {
  private var name: String
  private var status: FCStatusChip.Status
  private var zone: String
  private var tags: String
  private var time: String
  private var action: () -> Void
  private(set) var image: Image?

  public init(
    name: String,
    status: FCStatusChip.Status,
    zone: String,
    tags: String,
    time: String,
    action: @escaping () -> Void
  ) {
    self.name = name
    self.status = status
    self.zone = zone
    self.tags = tags
    self.time = time
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        thumbnail
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          Text(name)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          FCStatusChip(status)
        }
        FCZoneChip(zone) {}
          .allowsHitTesting(false)
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          Text(tags)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(time)
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .lineLimit(1)
      }
      .padding(FestiCoreSpacing.paddingP12)
      .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      .contentShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
    .buttonStyle(.plain)
  }

  private var thumbnail: some View {
    Group {
      if let image {
        image
          .resizable()
          .scaledToFill()
      } else {
        Image(asset: .flag20)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(FestiCoreSemanticColor.fillStrong.color)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: Metric.thumbnailHeight)
    .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    .accessibilityHidden(true)
  }
}

// MARK: - 체이닝 설정

public extension FCFlagTile {
  /// 깃발 사진을 바꾼 사본을 돌려준다.
  func image(_ image: Image?) -> Self {
    var copy = self
    copy.image = image
    return copy
  }
}

private extension FCFlagTile {
  enum Metric {
    static let thumbnailHeight: CGFloat = 88
    static let iconSize: CGFloat = 20
  }
}

#Preview {
  FCFlagTile(
    name: "호락호락",
    status: .active,
    zone: "리벳 앞 왼쪽",
    tags: "슬램 · 떼창",
    time: "5분 전"
  ) {}
    .frame(width: 165)
    .padding(FestiCoreSpacing.paddingP24)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
