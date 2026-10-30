//
//  FCFlagHero.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 상세 상단 히어로. 사진 위 아래쪽 그라데이션에 이름·팔로워·태그·팔로우 버튼·상태·소개를 올린다.
public struct FCFlagHero<Background: View>: View {
  private var name: String
  private var followers: String
  private var tags: [String]
  private var status: FCStatusChip.Status
  private var intro: String
  private var isFollowing: Bool
  private var onFollow: () -> Void
  private var background: Background

  public init(
    name: String,
    followers: String,
    tags: [String],
    status: FCStatusChip.Status,
    intro: String,
    isFollowing: Bool,
    onFollow: @escaping () -> Void,
    @ViewBuilder background: () -> Background
  ) {
    self.name = name
    self.followers = followers
    self.tags = tags
    self.status = status
    self.intro = intro
    self.isFollowing = isFollowing
    self.onFollow = onFollow
    self.background = background()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      Spacer(minLength: 0)
      HStack(alignment: .bottom, spacing: FestiCoreSpacing.paddingP12) {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
          HStack(alignment: .firstTextBaseline, spacing: FestiCoreSpacing.paddingP8) {
            Text(name)
              .festiCoreFont(.baseTitle2Bold)
              .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
            Text(followers)
              .festiCoreFont(.baseFootnoteMedium)
              .foregroundStyle(FestiCoreSemanticColor.staticalphaWhite80.color)
          }
          .lineLimit(1)
          HStack(spacing: FestiCoreSpacing.paddingP4) {
            ForEach(tags, id: \.self) { tag in
              FCTag(tag)
                .tone(.onImage)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        FCHeroFollowButton(
          isFollowing: isFollowing,
          action: onFollow
        )
      }
      FCStatusChip(status)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
        FestiCoreSemanticColor.staticalphaWhite40.color
          .frame(height: Metric.dividerHeight)
        Text(intro)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.staticalphaWhite80.color)
          .lineLimit(2)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .frame(maxWidth: .infinity)
    .frame(height: Metric.height)
    .background {
      ZStack {
        background
        LinearGradient(
          colors: [FestiCoreSemanticColor.staticBlack.color.opacity(0), FestiCoreSemanticColor.staticalphaBlack80.color],
          startPoint: .top,
          endPoint: .bottom
        )
      }
      .clipped()
    }
  }
}

private enum Metric {
  static let height: CGFloat = 360
  static let dividerHeight: CGFloat = 1
}

#Preview {
  FCFlagHero(
    name: "호락호락",
    followers: "팔로워 1,284",
    tags: ["슬램", "떼창", "초보 환영"],
    status: .active,
    intro: "“처음 와도 괜찮아요. 슬램은 앞쪽, 쉬고 싶으면 뒤쪽 깃발 아래로 오세요.”",
    isFollowing: false,
    onFollow: {}
  ) {
    FestiCoreSemanticColor.backgroundElevated.color
  }
  .preferredColorScheme(.dark)
}
