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
      // 잠금 화면 카드와 같은 규칙: 라임 강조, Bagel 헤드라인, 다음 내 일정과 남은 시간.
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          islandPhase(
            festivalID: context.attributes.festivalID,
            state: context.state,
            isStale: context.isStale
          )
        }
        DynamicIslandExpandedRegion(.trailing) {
          islandCrew(for: context.state)
        }
        DynamicIslandExpandedRegion(.bottom) {
          islandBottom(
            festivalID: context.attributes.festivalID,
            state: context.state,
            isStale: context.isStale
          )
        }
      } compactLeading: {
        Text(headline(
          for: context.state,
          isStale: context.isStale
        ))
          .font(WidgetFont.bagel(13))
          .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
          .lineLimit(1)
          .frame(
            maxWidth: Metric.compactLeadingWidth,
            alignment: .leading
          )
      } compactTrailing: {
        islandCompactTrailing(
          festivalID: context.attributes.festivalID,
          state: context.state
        )
      } minimal: {
        Image(systemName: "music.note")
          .font(.pretendardFontFamily(
            family: .Bold,
            size: 11
          ))
          .foregroundStyle(WidgetPalette.black)
          .frame(
            width: Metric.minimalSize,
            height: Metric.minimalSize
          )
          .background(
            FestiCoreSemanticColor.staticLime.color,
            in: Circle()
          )
      }
      .keylineTint(FestiCoreSemanticColor.staticLime.color)
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
        Text(phaseLabel(
          for: state,
          isStale: isStale
        ))
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
      if let stage = currentStageName(
        for: state,
        festivalID: festivalID
      ) {
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
        Text("다음 내 일정")
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
      nextCountdown(
        for: state,
        festivalID: festivalID,
        size: 24
      )
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
    if let next = resolvedNextMine(
      for: state,
      festivalID: festivalID
    ) {
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
      Text(state.phase == .finished ? "축제가 종료됐어요" : "저장한 공연이 없어요")
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 13
        ))
        .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
        .lineLimit(1)
    }
  }

  @ViewBuilder
  func islandPhase(
    festivalID: String,
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM2
    ) {
      Text(phaseLabel(
        for: state,
        isStale: isStale
      ))
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 9
        ))
        .tracking(0.9)
        .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      if let stage = currentStageName(
        for: state,
        festivalID: festivalID
      ) {
        Text(stage)
          .font(.pretendardFontFamily(
            family: .Medium,
            size: 11
          ))
          .foregroundStyle(FestiCoreSemanticColor.staticWhite.color.opacity(0.7))
          .lineLimit(1)
      }
    }
    .padding(
      .leading,
      FestiCoreSpacing.marginM4
    )
  }

  @ViewBuilder
  func islandCrew(for state: FestiCoreFestivalActivityAttributes.ContentState) -> some View {
    if state.pinnedFlag != nil || state.crewSummary != nil {
      HStack(spacing: FestiCoreSpacing.marginM2) {
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
      .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      .padding(
        .trailing,
        FestiCoreSpacing.marginM4
      )
    }
  }

  @ViewBuilder
  func islandBottom(
    festivalID: String,
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM8
    ) {
      Text(headline(
        for: state,
        isStale: false
      ))
        .font(WidgetFont.bagel(28))
        .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
        .rotationEffect(.degrees(-3))
        .opacity(isStale ? 0.4 : 1)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
      HStack(
        alignment: .center,
        spacing: FestiCoreSpacing.marginM8
      ) {
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.marginM2
        ) {
          Text("다음 내 일정")
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
        nextCountdown(
          for: state,
          festivalID: festivalID,
          size: 20
        )
      }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.marginM4
    )
  }

  @ViewBuilder
  func islandCompactTrailing(
    festivalID: String,
    state: FestiCoreFestivalActivityAttributes.ContentState
  ) -> some View {
    if let next = resolvedNextMine(
      for: state,
      festivalID: festivalID
    ), let start = performanceDate(next.startsAt), start > .now {
      // 좁은 영역이라 다음 내 일정까지 남은 시간을 타이머로 줄여 보인다.
      Text(
        start,
        style: .timer
      )
        .font(WidgetFont.bagel(13))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
        .frame(
          maxWidth: Metric.compactTrailingWidth,
          alignment: .trailing
        )
    } else {
      Text(shortStatusText(for: state))
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 12
        ))
        .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
    }
  }

  @ViewBuilder
  func nextCountdown(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    festivalID: String,
    size: CGFloat
  ) -> some View {
    if let next = resolvedNextMine(
      for: state,
      festivalID: festivalID
    ), let start = performanceDate(next.startsAt) {
      Text(
        start,
        style: .relative
      )
        .font(WidgetFont.bagel(size))
        .minimumScaleFactor(0.65)
        .lineLimit(1)
        .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
    }
  }

  /// 서버 payload에 다음 내 일정이 없으면 앱과 공유한 저장 일정으로 채운다.
  func resolvedNextMine(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    festivalID: String
  ) -> FestiCoreFestivalActivityAttributes.ContentState.NextMine? {
    return state.nextMine ?? FestivalActivityWidgetContent.nextMine(
      snapshot: FestivalWidgetStore.load(),
      festivalID: festivalID,
      now: .now
    )
  }

  func phaseLabel(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> String {
    if isStale { return "오래된 정보" }
    switch state.phase {
    case .upcoming: return "UP NEXT"
    case .ongoing: return "NOW PLAYING"
    case .finished: return "SEE YOU"
    }
  }

  func currentStageName(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    festivalID: String
  ) -> String? {
    return state.nowStages.first.flatMap { stage in
      return stage.stageName ?? stageName(
        for: stage.setId,
        festivalID: festivalID
      )
    }
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

private extension FestiCoreFestivalActivityWidget {
  enum Metric {
    static let compactLeadingWidth: CGFloat = 72
    static let compactTrailingWidth: CGFloat = 56
    static let minimalSize: CGFloat = 22
  }
}
