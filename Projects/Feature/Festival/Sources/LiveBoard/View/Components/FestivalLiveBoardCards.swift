import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// 내 크루 카드. 멤버 행은 `FCCrewRow`와 같은 구성이며 구역이 없으면 칩을 그리지 않는다.
struct FestivalLiveBoardCrewCard: View {
  let crew: FestivalLiveBoardPresentation.Crew

  var body: some View {
    VStack(spacing: .zero) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(crew.title)
          .festiCoreFont(.baseBodyBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(crew.subtitle)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(EdgeInsets(
        top: FestiCoreSpacing.paddingP16, leading: FestiCoreSpacing.paddingP16,
        bottom: FestiCoreSpacing.paddingP8, trailing: FestiCoreSpacing.paddingP16
      ))
      ForEach(Array(crew.members.enumerated()), id: \.element.id) { index, member in
        memberRow(member, tint: Self.tints[index % Self.tints.count])
      }
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}

private extension FestivalLiveBoardCrewCard {
  static let tints: [FCAvatar.Tint] = [.blue, .pink, .orange, .green, .purple, .yellow]

  func memberRow(_ member: FestivalLiveBoardPresentation.CrewMember, tint: FCAvatar.Tint) -> some View {
    let primary = member.isLeaving ? FestiCoreSemanticColor.labelAssistive : .labelNormal
    return HStack(spacing: FestiCoreSpacing.paddingP16) {
      FCAvatar(member.nickname)
        .tint(tint)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          Text(member.nickname)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(primary.color)
          if member.isMe {
            FCTag("나")
          }
        }
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          if let zone = member.zone {
            FCZoneChip(zone) {}
              .allowsHitTesting(false)
          }
          if let status = member.status {
            Text(status)
              .festiCoreFont(.baseFootnoteBold)
              .foregroundStyle(primary.color)
          }
        }
      }
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
      if let time = member.time {
        Text(time)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(member.isLeaving
            ? FestiCoreSemanticColor.labelDisable.color
            : FestiCoreSemanticColor.labelAssistive.color)
      }
    }
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .opacity(member.isLeaving ? 0.6 : 1)
    .accessibilityElement(children: .combine)
  }
}

/// 팔로우한 깃발 타일. `FCFlagTile`과 같은 구성이며 썸네일은 서버 URL로 그린다.
struct FestivalLiveBoardFlagTile: View {
  let flag: FestivalLiveBoardPresentation.Flag

  var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      FestivalLiveBoardFlagThumbnail(url: flag.thumbnailURL)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        Text(flag.name)
          .festiCoreFont(.baseCalloutBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        if let status = flag.status {
          FCStatusChip(status.chip)
        }
      }
      if let zone = flag.zone {
        FCZoneChip(zone) {}
          .allowsHitTesting(false)
      }
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(flag.tags)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity, alignment: .leading)
        if let time = flag.time {
          Text(time)
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
      }
      .lineLimit(1)
    }
    .padding(FestiCoreSpacing.paddingP12)
    .frame(width: 156, alignment: .topLeading)
    .frame(minHeight: 204, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    .accessibilityElement(children: .combine)
  }
}

/// 활성 깃발 행. `FCActiveFlagRow`와 같은 구성이며 썸네일은 서버 URL로 그린다.
struct FestivalLiveBoardActiveFlagRow: View {
  let flag: FestivalLiveBoardPresentation.Flag

  var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      FestivalLiveBoardFlagThumbnail(url: flag.thumbnailURL)
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(flag.name)
          .festiCoreFont(.baseCalloutBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        if !flag.meta.isEmpty {
          Text(flag.meta)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
      }
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .trailing, spacing: FestiCoreSpacing.paddingP4) {
        if let status = flag.status {
          FCStatusChip(status.chip)
        }
        if let time = flag.time {
          Text(time)
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
      }
    }
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .accessibilityElement(children: .combine)
  }
}

/// 로그아웃 상태에서 크루·팔로우 자리에 보이는 로그인 카드.
struct FestivalLiveBoardLoginCard: View {
  let title: String
  let action: () -> Void

  var body: some View {
    FCListRow(title, action: action)
      .background(FestiCoreSemanticColor.backgroundElevated.color)
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}

private struct FestivalLiveBoardFlagThumbnail: View {
  let url: URL?

  var body: some View {
    if url != nil {
      FCRemoteImage(url: url)
    } else {
      Image(asset: .flag20)
        .resizable()
        .frame(width: 20, height: 20)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FestiCoreSemanticColor.fillStrong.color)
        .accessibilityHidden(true)
    }
  }
}

private extension FestivalLiveBoardPresentation.FlagStatus {
  var chip: FCStatusChip.Status {
    switch self {
    case .active: .active
    case .resting: .resting
    case .ended: .endedToday
    }
  }
}
