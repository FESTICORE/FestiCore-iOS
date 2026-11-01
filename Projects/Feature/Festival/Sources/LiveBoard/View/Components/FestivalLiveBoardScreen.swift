import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

/// S01 라이브 보드. 시각은 서버 시각으로 보정하고 30초마다 다시 계산한다.
struct FestivalLiveBoardScreen: View {
  let festival: FestivalOverview
  let pack: FestivalPackDocument?
  let liveBoard: FestivalLiveBoardSnapshot?
  let liveBoardUnavailable: Bool
  let liveBoardUnpublished: Bool
  let isPackLoading: Bool
  let liveBoardClockAnchorAt: Date?
  let liveBoardReceivedAt: Date?
  let hasSession: Bool
  let sessionUserID: String?
  let mySetIDs: Set<String>
  let myScheduleUnavailable: Bool
  let liveActivityState: FestivalFeature.LiveActivityControlState
  let onLiveActivityTap: () -> Void
  let onLoginTap: () -> Void
  let onRetryMySchedule: () -> Void
  let onSwipeBack: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { timeline in
      let now = FestivalLiveBoardPresentation.serverNow(
        serverAt: liveBoard?.serverAt, clockAnchorAt: liveBoardClockAnchorAt, deviceNow: timeline.date
      )
      VStack(spacing: .zero) {
        FCTopBar(.back, title: "라이브 보드")
          .onBack(onSwipeBack)
        if liveBoardUnavailable, liveBoard != nil {
          FCOfflineBadge(FestivalLiveBoardPresentation.offlineText(
            receivedAt: liveBoardReceivedAt, deviceNow: timeline.date
          ))
        }
        ScrollView {
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
            festivalHeader(now: now)
            if liveBoardUnpublished {
              FCEmptyCard(
                icon: .music24,
                title: "라이브 보드 공개 전이에요",
                message: "축제 라이브 보드가 아직 공개되지 않았어요. 공개 후 공연과 깃발 현황을 확인해 주세요."
              )
            } else {
              if isPackLoading {
                FestivalLiveBoardSkeletonView()
              } else {
                scheduleCards(now: now, deviceNow: timeline.date)
              }
              if myScheduleUnavailable {
                HStack(spacing: FestiCoreSpacing.paddingP8) {
                  Text("내 일정을 불러오지 못했습니다.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                  Button("다시 시도", action: onRetryMySchedule)
                    .festiCoreFont(.baseCaption1Bold)
                }
                .festiCoreFont(.baseCaption1Regular)
                .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
              }
              if !isPackLoading {
                FestivalLiveBoardView(
                  rows: pack.map {
                    FestivalLiveBoardPresentation.stageRows(
                      FestivalLiveBoardSchedule.resolve(pack: $0, now: now), mySetIDs: mySetIDs
                    )
                  } ?? [],
                  updated: FestivalLiveBoardPresentation.relativeTime(liveBoardReceivedAt, now: timeline.date),
                  source: FestivalLiveBoardPresentation.sourceLine(pack?.source)
                )
              }
              crewSection(now: now)
              if pack?.flagsEnabled != false {
                followedSection(now: now)
                activeSection(now: now)
              }
              liveActivityControl
            }
          }
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
          .padding(.top, FestiCoreSpacing.paddingP16)
          .padding(.bottom, FestiCoreSpacing.paddingP24)
        }
        .scrollIndicators(.hidden)
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
    .overlay(alignment: .leading) {
      Color.clear
        .contentShape(Rectangle())
        .frame(width: 24)
        .gesture(
          DragGesture(minimumDistance: 25)
            .onEnded { value in
              guard value.translation.width > 80,
                    value.translation.width > abs(value.translation.height) * 1.5 else { return }
              onSwipeBack()
            }
        )
        .accessibilityHidden(true)
    }
  }
}

private extension FestivalLiveBoardScreen {
  func festivalHeader(now: Date) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
      Text(festival.name)
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      if let dayLine = FestivalLiveBoardPresentation.dayLine(pack: pack, festival: festival, now: now) {
        Text(dayLine)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  func scheduleCards(now: Date, deviceNow: Date) -> some View {
    let countdown = FestivalLiveBoardPresentation.countdown(pack: pack, festival: festival, now: now)
    if let countdown {
      FCCountdownCard(label: "개장까지", time: countdown.time, sub: countdown.sub)
    }
    if let card = FestivalLiveBoardPresentation.setCard(
      pack: pack, mySetIDs: mySetIDs, isBeforeOpening: countdown != nil, now: now
    ) {
      FCNextSetCard(
        artist: card.artist,
        meta: card.meta,
        remain: card.remain,
        updated: FestivalLiveBoardPresentation.updatedText(receivedAt: liveBoardReceivedAt, deviceNow: deviceNow),
        progress: card.progress
      )
      .label(card.label)
    } else {
      FCEmptyCard(
        icon: .music24,
        title: "다음 공연이 없습니다",
        message: pack == nil ? "시간표를 불러오면 다음 공연을 볼 수 있어요." : "공식 시간표에 예정된 공연이 없습니다."
      )
    }
  }

  @ViewBuilder
  func crewSection(now: Date) -> some View {
    if !hasSession {
      FestivalLiveBoardLoginCard(title: "크루와 함께 보려면 로그인", action: onLoginTap)
    } else if let crew = liveBoard?.crew {
      FestivalLiveBoardCrewCard(crew: FestivalLiveBoardPresentation.crew(
        crew, sessionUserID: sessionUserID, zoneName: { pack?.zoneName(for: $0) }, now: now
      ))
    } else if liveBoard == nil {
      FCEmptyCard(title: "내 크루", message: loadingMessage)
    } else {
      FCEmptyCard(title: "아직 크루가 없어요", message: "친구를 초대하면 서로 어느 존에 있는지 바로 볼 수 있어요.")
    }
  }

  func followedSection(now: Date) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      FCSectionHeader("팔로우한 깃발")
      if !hasSession {
        FestivalLiveBoardLoginCard(title: "깃발을 팔로우하려면 로그인", action: onLoginTap)
      } else if let followed = liveBoard?.followedFlags, !followed.isEmpty {
        ScrollView(.horizontal) {
          HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP12) {
            ForEach(followed) { flag in
              FestivalLiveBoardFlagTile(flag: presentation(flag, now: now))
            }
          }
          .padding(.trailing, FestiCoreSpacing.paddingP16)
        }
        .scrollIndicators(.hidden)
      } else if liveBoard == nil {
        FCEmptyCard(icon: .flag20, title: "팔로우한 깃발", message: loadingMessage)
      } else {
        FCEmptyCard(icon: .flag20, title: "만나보고 싶은 깃발이 있나요?", message: "팔로우하면 깃발이 움직일 때 조용히 알려 드려요.")
      }
    }
  }

  func activeSection(now: Date) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      FCSectionHeader("활성 깃발")
        .action("최근 업데이트 순")
      if let active = liveBoard?.activeFlags, !active.isEmpty {
        VStack(spacing: .zero) {
          ForEach(FestivalLiveBoardPresentation.sortedActiveFlags(active)) { flag in
            FestivalLiveBoardActiveFlagRow(flag: presentation(flag, now: now))
          }
        }
        .background(FestiCoreSemanticColor.backgroundElevated.color)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      } else if liveBoard == nil {
        FCEmptyCard(icon: .flag20, title: "활성 깃발", message: loadingMessage)
      } else {
        FCEmptyCard(icon: .flag20, title: "활동 중인 깃발이 없어요", message: "깃발이 움직이면 여기에서 바로 보여 드려요.")
      }
    }
  }

  func presentation(_ flag: FestivalLiveBoardSnapshot.Flag, now: Date) -> FestivalLiveBoardPresentation.Flag {
    FestivalLiveBoardPresentation.flag(flag, zoneName: { pack?.zoneName(for: $0) }, now: now)
  }

  var loadingMessage: String {
    liveBoardUnavailable ? "실시간 정보를 불러올 수 없습니다. 잠시 후 다시 시도합니다." : "실시간 정보를 불러오는 중입니다."
  }

  var liveActivityControl: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Button(liveActivityState.title, action: onLiveActivityTap)
        .festiCoreFont(.baseBodyBold)
        .frame(maxWidth: .infinity)
        .padding(FestiCoreSpacing.paddingP16)
        .foregroundStyle(FestiCoreSemanticColor.primaryOnPrimary.color)
        .background(FestiCoreSemanticColor.primaryNormal.color,
                    in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
        .disabled(!liveActivityState.isEnabled)
        .opacity(liveActivityState.isEnabled ? 1 : 0.5)
      if let message = liveActivityState.message {
        Text(message)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
    }
  }
}
