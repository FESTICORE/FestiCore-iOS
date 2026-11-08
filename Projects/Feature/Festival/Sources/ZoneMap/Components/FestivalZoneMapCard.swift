//
//  FestivalZoneMapCard.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreDesignKit
import SwiftUI

/// Figma S06 B~E 존 카드. 고른 존의 깃발·크루를 보여 준다.
struct FestivalZoneMapCard: View {
  let card: FestivalZoneMapModel.Card

  var body: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.stackSpacing
    ) {
      header
      Spacer()
        .frame(height: Metric.headerGap)
      if card.isEmpty {
        infoLine("지금 이 존에 있는 깃발·크루가 없어요.")
      } else {
        ForEach(card.flags) { flag in
          FCActiveFlagRow(
            name: flag.name,
            meta: flag.meta,
            time: flag.time,
            status: flag.status
          ) {}
        }
        ForEach(card.crew) { member in
          FCCrewRow(
            name: member.nickname,
            zone: member.zone,
            status: member.status,
            time: member.time
          )
          .avatarTint(member.tint)
          .isMe(member.isMe)
          .isStale(member.isStale)
        }
        if card.hasStaleCrew {
          infoLine("30분 넘게 소식이 없어서 흐리게 보여요.")
        }
      }
      if card.isEmpty || card.hasStaleCrew {
        Spacer()
          .frame(height: Metric.infoBottomGap)
      }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(
      .top,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .bottom,
      Metric.bottomPadding
    )
    // 그림자는 카드 배경에만 준다. 컨테이너에 주면 행마다 그림자가 따로 생긴다.
    .background {
      RoundedRectangle(cornerRadius: FestiCoreRadius.r20)
        .fill(FestiCoreSemanticColor.backgroundElevated.color)
        .shadow(
          color: FestiCoreSemanticColor.staticBlack.color.opacity(Metric.shadowOpacity),
          radius: Metric.shadowRadius,
          y: Metric.shadowY
        )
    }
  }
}

private extension FestivalZoneMapCard {
  var header: some View {
    return HStack(spacing: FestiCoreSpacing.marginM8) {
      Image(asset: .locationDot20)
        .resizable()
        .frame(
          width: Metric.icon,
          height: Metric.icon
        )
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(
          width: Metric.iconWrap,
          height: Metric.iconWrap
        )
        .background(
          FestiCoreSemanticColor.fillNormal.color,
          in: Circle()
        )
        .accessibilityHidden(true)
      VStack(
        alignment: .leading,
        spacing: Metric.titleSpacing
      ) {
        Text(card.name)
          .festiCoreFont(.baseHeadlineBold)
          .festiCoreLineBox(.baseHeadlineBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(card.meta)
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .lineLimit(1)
    }
  }

  func infoLine(_ text: String) -> some View {
    return HStack(spacing: FestiCoreSpacing.marginM6) {
      Image(asset: .circleInfo16)
        .resizable()
        .frame(
          width: Metric.infoIcon,
          height: Metric.infoIcon
        )
        .accessibilityHidden(true)
      Text(text)
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
    }
    .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  enum Metric {
    static let icon: CGFloat = 20
    static let iconWrap: CGFloat = 36
    static let infoIcon: CGFloat = 16
    static let titleSpacing: CGFloat = 4
    static let stackSpacing: CGFloat = 4
    static let headerGap: CGFloat = 4
    static let infoBottomGap: CGFloat = 8
    static let bottomPadding: CGFloat = 8
    /// Figma 카드 그림자는 아래 3pt 정도만 옅게 보인다.
    static let shadowOpacity: Double = 0.12
    static let shadowRadius: CGFloat = 2
    static let shadowY: CGFloat = 1
  }
}

/// Figma S06 I. 지도 영역이 없는 팩은 존 목록으로 보여 준다.
struct FestivalZoneMapList: View {
  let rows: [(id: String, name: String, value: String)]
  let onTap: (String) -> Void

  var body: some View {
    VStack(spacing: .zero) {
      ForEach(
        Array(rows.enumerated()),
        id: \.element.id
      ) { index, row in
        if index > 0 {
          FCDivider()
            .padding(
              .horizontal,
              FestiCoreSpacing.paddingP16
            )
        }
        FCListRow(row.name) { onTap(row.id) }
          .value(row.value)
      }
    }
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
  }
}
