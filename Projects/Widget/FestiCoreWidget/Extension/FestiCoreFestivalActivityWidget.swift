import FestiCoreDesignKit
import ActivityKit
import FestiCoreUtility
import FestiCoreLiveActivity
import SwiftUI
import WidgetKit

struct FestiCoreFestivalActivityWidget: Widget {
  var body: some WidgetConfiguration {
    return ActivityConfiguration(for: FestiCoreFestivalActivityAttributes.self) { context in
      lockScreenCard(
        festivalID: context.attributes.festivalID,
        state: context.state,
        isStale: context.isStale
      )
      .activityBackgroundTint(WidgetPalette.black)
      .activitySystemActionForegroundColor(FestiCoreSemanticColor.staticLime.color)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "sparkle")
            .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.festivalName)
            .font(.pretendardFontFamily(
              family: .Bold,
              size: 13
            ))
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(
            alignment: .leading,
            spacing: FestiCoreSpacing.marginM4
          ) {
            Text(headline(
              for: context.state,
              isStale: context.isStale
            ))
              .font(.pretendardFontFamily(
                family: .Bold,
                size: 13
              ))
            nextSchedule(
              for: context.state,
              festivalID: context.attributes.festivalID
            )
          }
        }
      } compactLeading: {
        Image(systemName: "sparkle")
          .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      } compactTrailing: {
        Text(shortStatusText(for: context.state))
          .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      } minimal: {
        Image(systemName: "sparkle")
          .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      }
    }
  }
}

private extension FestiCoreFestivalActivityWidget {
  @ViewBuilder
  func lockScreenCard(
    festivalID: String,
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    VStack(spacing: 0) {
      nowPlayingPanel(
        festivalID: festivalID,
        state: state,
        isStale: isStale
      )
        .frame(
          maxWidth: .infinity,
          minHeight: 108,
          maxHeight: 108
        )
        .background(FestiCoreSemanticColor.staticLime.color)
      nextPanel(
        festivalID: festivalID,
        state: state,
        isStale: isStale
      )
        .frame(
          maxWidth: .infinity,
          minHeight: 48,
          maxHeight: 48
        )
        .background(WidgetPalette.black)
    }
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(
      cornerRadius: FestiCoreRadius.r24,
      style: .continuous
    ))
    .environment(
      \.colorScheme,
      .dark
    )
  }

  @ViewBuilder
  func nowPlayingPanel(
    festivalID: String,
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM4
    ) {
      HStack(alignment: .firstTextBaseline) {
        Text(isStale ? "오래된 정보" : state.phase == .upcoming ? "UP NEXT" : state.phase == .finished ? "SEE YOU" : "NOW PLAYING")
          .font(.pretendardFontFamily(
            family: .Bold,
            size: 9
          ))
          .tracking(0.9)
        Spacer(minLength: FestiCoreSpacing.marginM4)
        if state.pinnedFlag != nil || state.crewSummary != nil {
          Image(systemName: "star.fill")
            .font(.pretendardFontFamily(
              family: .Bold,
              size: 10
            ))
          Text(state.crewSummary?.name ?? "내 깃발")
            .font(.pretendardFontFamily(
              family: .Medium,
              size: 10
            ))
            .lineLimit(1)
        }
      }
      if let stage = state.nowStages.first.flatMap({ $0.stageName ?? stageName(
        for: $0.setId,
        festivalID: festivalID
      ) }) {
        Text(stage)
          .font(.pretendardFontFamily(
            family: .Medium,
            size: 11
          ))
          .lineLimit(1)
      }
      Text(headline(
        for: state,
        isStale: false
      ))
        .font(WidgetFont.bagel(34))
        .rotationEffect(.degrees(-3))
        .opacity(isStale ? 0.4 : 1)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
    .foregroundStyle(WidgetPalette.black)
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
    )
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }

  @ViewBuilder
  func nextPanel(
    festivalID: String,
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    HStack(
      alignment: .center,
      spacing: FestiCoreSpacing.marginM8
    ) {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.marginM2
      ) {
        Text(nextPanelTitle(for: state))
          .font(.pretendardFontFamily(
            family: .Medium,
            size: 10
          ))
          .foregroundStyle(FestiCoreSemanticColor.staticWhite.color.opacity(0.7))
        nextSchedule(
          for: state,
          festivalID: festivalID
        )
      }
      Spacer(minLength: FestiCoreSpacing.marginM4)
      if let next = state.nextMine,
         let start = performanceDate(next.startsAt) {
        Text(
          start,
          style: .relative
        )
          .font(WidgetFont.bagel(24))
          .minimumScaleFactor(0.65)
          .lineLimit(1)
          .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      }
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
    )
  }

  @ViewBuilder
  func nextSchedule(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    festivalID: String
  ) -> some View {
    if let next = state.nextMine {
      Text([next.artist, next.stageName ?? stageName(
        for: next.setId,
        festivalID: festivalID
      ), performanceDate(next.startsAt)?.formatted(.time)]
        .compactMap { $0 }
        .joined(separator: " · "))
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 13
        ))
        .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
        .lineLimit(1)
    } else {
      Text(currentPerformanceDescription(for: state) ?? (state.phase == .finished ? "축제가 종료됐어요" : "예정된 공연이 없어요"))
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 13
        ))
        .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
        .lineLimit(1)
    }
  }

  func nextPanelTitle(
    for state: FestiCoreFestivalActivityAttributes.ContentState
  ) -> String {
    guard let next = state.nextMine else {
      return state.nowStages.isEmpty ? "다음 공연" : "현재 공연"
    }
    return next.isSaved == false ? "다음 공연" : "다음 내 일정"
  }

  func currentPerformanceDescription(
    for state: FestiCoreFestivalActivityAttributes.ContentState
  ) -> String? {
    guard let current = state.nowStages.first else { return nil }
    return [current.artist, current.stageName, performanceDate(current.startsAt)?.formatted(.time)]
      .compactMap { $0 }
      .joined(separator: " · ")
  }

  func headline(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> String {
    if isStale { return "정보를 확인해 주세요" }
    if state.phase == .ongoing, let end = state.endDate,
       end > .now, end.timeIntervalSinceNow <= 3600 { return "귀가 준비!" }
    if let current = state.nowStages.first { return current.artist }
    switch state.phase {
    case .upcoming: return "\(state.startDate.formatted(.time)) 공연 시작"
    case .ongoing: return "공연 진행 중"
    case .finished: return "오늘 끝!"
    }
  }

  func shortStatusText(for state: FestiCoreFestivalActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .upcoming: return "예정"
    case .ongoing: return "진행"
    case .finished: return "종료"
    }
  }

  func stageName(
    for setID: String,
    festivalID: String
  ) -> String? {
    guard let snapshot = FestivalWidgetStore.load(), snapshot.festivalID == festivalID else { return nil }
    return snapshot.performances.first { $0.id == setID }?.stageName
  }

  func performanceDate(_ value: String) -> Date? {
    return value.isoDate
  }
}
