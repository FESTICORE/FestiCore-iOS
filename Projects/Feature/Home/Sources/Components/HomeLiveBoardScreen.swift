import FestiCoreDesignKit
import SwiftUI

struct HomeLiveBoardScreen: View {
  let festival: FestivalOverview
  let pack: FestivalPackDocument?
  let imageRevision: Int
  let imageURL: (String?) -> URL?
  let liveActivityState: HomeFeature.LiveActivityControlState
  let onLiveActivityTap: () -> Void
  let onBack: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        header
        festivalHeader
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
          let stages = pack.map { HomeLiveBoardSchedule.resolve(pack: $0, now: timeline.date) } ?? []
          nextSchedule(stages: stages)
        }
        if let pack {
          HomeLiveBoardView(pack: pack)
        } else {
          emptySection(title: "지금 무대", message: "공연 시간표를 불러오면 무대 현황을 볼 수 있습니다.")
        }
        emptySection(title: "크루 플래그", message: "표시할 크루 플래그 정보가 없습니다.")
        emptySection(title: "팔로우한 아티스트", message: "표시할 팔로우 아티스트 정보가 없습니다.")
        emptySection(title: "진행 중인 플래그", message: "표시할 플래그 정보가 없습니다.")
        liveActivityControl
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP20)
      .padding(.top, FestiCoreSpacing.paddingP16)
      .padding(.bottom, FestiCoreSpacing.paddingP24)
    }
    .scrollIndicators(.hidden)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var header: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      Button(action: onBack) {
        Image(systemName: "chevron.left")
          .festiCoreFont(.baseHeadlineBold)
          .frame(width: 32, height: 40)
      }
      .accessibilityLabel("축제 목록으로 돌아가기")
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
    HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP16) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        Text(festival.name)
          .festiCoreFont(.baseTitle1Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .fixedSize(horizontal: false, vertical: true)
        if let dayLabel {
          Text(dayLabel)
            .festiCoreFont(.baseSubheadlineBold)
            .foregroundStyle(FestiCoreSemanticColor.accentForegroundLime.color)
        }
        if let dateLabel {
          Text(dateLabel)
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
      }
      Spacer(minLength: 0)
      if let thumbnail = imageURL(pack?.thumbUrl ?? festival.thumbnailURL?.absoluteString) {
        HomePosterView(url: thumbnail, imageRevision: imageRevision)
          .frame(width: 64, height: 64)
      }
    }
  }

  private func nextSchedule(stages: [HomeLiveBoardSchedule.Stage]) -> some View {
    let next = stages.compactMap { stage -> (String, HomeLiveBoardSchedule.Slot)? in
      stage.next.map { (stage.name, $0) }
    }.min { $0.1.startsAt < $1.1.startsAt }

    return VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Label("다음 일정", systemImage: "clock")
        .festiCoreFont(.baseSubheadlineBold)
      if let next {
        Text(next.1.artist)
          .festiCoreFont(.baseTitle2Bold)
          .lineLimit(2)
        Text("\(next.0) · \(HomeDateFormat.time(from: next.1.startsAt))")
          .festiCoreFont(.baseSubheadlineMedium)
      } else {
        Text(pack == nil ? "공연 시간표를 불러오면 다음 일정을 볼 수 있습니다." : "예정된 공연이 없습니다.")
          .festiCoreFont(.baseSubheadlineRegular)
      }
    }
    .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.staticLime.color,
                in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }

  private func emptySection(title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(title)
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text(message)
        .festiCoreFont(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FestiCoreSpacing.paddingP20)
        .background(FestiCoreSemanticColor.backgroundElevated.color,
                    in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
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
    let packDays = (pack?.days ?? []).compactMap(\.date).filter { HomeDateFormat.day(from: $0) != nil }
    if !packDays.isEmpty { return Array(Set(packDays)).sorted() }
    return [festival.firstDate, festival.lastDate].compactMap { $0 }
      .filter { HomeDateFormat.day(from: $0) != nil }
  }

  private var selectedDate: String? {
    let today = HomeDateFormat.calendar.startOfDay(for: .now)
    return dates.first { HomeDateFormat.day(from: $0) == today } ?? dates.first
  }

  private var dayLabel: String? {
    guard let selectedDate, let index = dates.firstIndex(of: selectedDate) else { return nil }
    return "DAY \(index + 1)"
  }

  private var dateLabel: String? {
    guard let selectedDate else { return nil }
    return HomeDateFormat.festivalDay(from: selectedDate)
  }
}
