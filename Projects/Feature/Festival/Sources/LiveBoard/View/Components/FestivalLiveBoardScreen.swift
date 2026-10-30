import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

struct FestivalLiveBoardScreen: View {
  let festival: FestivalOverview
  let pack: FestivalPackDocument?
  let liveBoard: FestivalLiveBoardSnapshot?
  let liveBoardUnavailable: Bool
  let liveActivityState: FestivalFeature.LiveActivityControlState
  let onLiveActivityTap: () -> Void
  let onSwipeBack: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        header
        festivalHeader
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
          let stages = pack.map { FestivalLiveBoardSchedule.resolve(pack: $0, now: timeline.date) } ?? []
          nextSchedule(stages: stages, now: timeline.date)
        }
        if let pack {
          FestivalLiveBoardView(pack: pack)
        } else {
          emptySection(title: "지금 무대", message: "공연 시간표를 불러오면 무대 현황을 볼 수 있습니다.")
        }
        crewSection
        flagSection(title: "팔로우한 깃발", flags: liveBoard?.followedFlags ?? [])
        flagSection(title: "활성 깃발", flags: liveBoard?.activeFlags ?? [])
        liveActivityControl
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP20)
      .padding(.top, FestiCoreSpacing.paddingP16)
      .padding(.bottom, FestiCoreSpacing.paddingP24)
    }
    .scrollIndicators(.hidden)
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

  private var header: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      Text("FESTICORE")
        .festiCoreFont(.baseTitle3Bold)
        .tracking(-0.5)
      Spacer()
      Image(systemName: "bell")
        .festiCoreFont(.baseTitle3Medium)
        .accessibilityHidden(true)
    }
    .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
  }

  private var festivalHeader: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
      Text(festival.name)
        .festiCoreFont(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      if let dayLabel, let dateLabel {
        Text("\(dayLabel) · \(dateLabel)")
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func nextSchedule(stages: [FestivalLiveBoardSchedule.Stage], now: Date) -> some View {
    let next = stages.compactMap { stage -> (String, FestivalLiveBoardSchedule.Slot)? in
      stage.next.map { (stage.name, $0) }
    }.min { $0.1.startsAt < $1.1.startsAt }

    return Group {
      if let next {
        FCNextSetCard(
          artist: next.1.artist,
          meta: "\(next.0) · \(next.1.startsAt.formatted(.time))",
          remain: remainingTime(until: next.1.startsAt, now: now),
          updated: "시간표 기준",
          progress: 0
        )
        .label("다음 공연")
      } else {
        FCEmptyCard(
          title: "다음 공연이 없습니다",
          message: pack == nil ? "시간표를 불러오면 다음 공연을 볼 수 있어요." : "공식 시간표에 예정된 공연이 없습니다."
        )
      }
    }
  }

  private func remainingTime(until date: Date, now: Date) -> String {
    let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
    if minutes < 60 { return "\(minutes)분 후" }
    let hours = minutes / 60
    return hours < 24 ? "\(hours)시간 후" : "\(hours / 24)일 후"
  }

  private func emptySection(title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(title)
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      FCEmptyCard(title: title, message: message)
    }
  }

  private var crewSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text("내 크루 · 확인이들")
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      if let crew = liveBoard?.crew {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
          Text(crew.name)
            .festiCoreFont(.baseHeadlineBold)
          ForEach(crew.members) { member in
            HStack {
              Text(member.nickname)
              Spacer()
              Text(member.zoneID ?? member.state)
                .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            }
            .festiCoreFont(.baseSubheadlineRegular)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FestiCoreSemanticColor.backgroundElevated.color,
                    in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      } else {
        FCEmptyCard(title: "내 크루", message: liveBoardMessage(empty: "참여 중인 크루가 없습니다."))
      }
    }
    .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
  }

  private func flagSection(title: String, flags: [FestivalLiveBoardSnapshot.Flag]) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(title)
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      if flags.isEmpty {
        FCEmptyCard(title: title, message: liveBoardMessage(empty: "표시할 깃발이 없습니다."))
      } else {
        ForEach(flags) { flag in
          HStack(spacing: FestiCoreSpacing.paddingP12) {
            FCRemoteImage(url: flag.thumbnailURL)
              .frame(width: 48, height: 48)
              .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
            VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
              Text(flag.name)
                .festiCoreFont(.baseSubheadlineBold)
                .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              Text([flag.zoneID, flag.activity, flagStatus(flag.status)]
                .compactMap { $0 }.joined(separator: " · "))
                .festiCoreFont(.baseCaption1Regular)
                .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            }
            Spacer(minLength: 0)
          }
          .padding(FestiCoreSpacing.paddingP12)
          .background(FestiCoreSemanticColor.backgroundElevated.color,
                      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        }
      }
    }
  }

  private func liveBoardMessage(empty: String) -> String {
    guard liveBoard == nil else { return empty }
    return liveBoardUnavailable ? "실시간 정보를 불러올 수 없습니다. 잠시 후 다시 시도합니다." : "실시간 정보를 불러오는 중입니다."
  }

  private func flagStatus(_ status: String) -> String? {
    switch status {
    case "active": "활동 중"
    case "resting": "휴식 중"
    case "ended": "종료"
    default: nil
    }
  }

  private var liveActivityControl: some View {
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

  private var dates: [String] {
    let packDays = (pack?.days ?? []).compactMap(\.date).filter { $0.date(as: .day) != nil }
    if !packDays.isEmpty { return Array(Set(packDays)).sorted() }
    return [festival.firstDate, festival.lastDate].compactMap { $0 }
      .filter { $0.date(as: .day) != nil }
  }

  private var selectedDate: String? {
    let today = FestivalDateFormat.calendar.startOfDay(for: .now)
    return dates.first { $0.date(as: .day) == today } ?? dates.first
  }

  private var dayLabel: String? {
    guard let selectedDate, let index = dates.firstIndex(of: selectedDate) else { return nil }
    return "DAY \(index + 1)"
  }

  private var dateLabel: String? {
    guard let selectedDate else { return nil }
    return selectedDate.date(as: .day)?.formatted(.festivalDay)
  }
}
