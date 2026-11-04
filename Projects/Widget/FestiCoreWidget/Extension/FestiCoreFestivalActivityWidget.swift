import ActivityKit
import CoreText
import FestiCoreLiveActivity
import SwiftUI
import WidgetKit

struct FestiCoreFestivalActivityWidget: Widget {
  var body: some WidgetConfiguration {
    return ActivityConfiguration(for: FestiCoreFestivalActivityAttributes.self) { context in
      lockScreenCard(
        festivalName: context.attributes.festivalName,
        state: context.state,
        isStale: context.isStale
      )
      .activityBackgroundTint(Metric.black)
      .activitySystemActionForegroundColor(Metric.lime)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "sparkle")
            .foregroundStyle(Metric.lime)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.festivalName)
            .font(WidgetFont.pretendardBold(13))
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(
            alignment: .leading,
            spacing: 4
          ) {
            Text(headline(
              for: context.state,
              isStale: context.isStale
            ))
              .font(WidgetFont.pretendardBold(13))
            nextSchedule(for: context.state)
          }
        }
      } compactLeading: {
        Image(systemName: "sparkle")
          .foregroundStyle(Metric.lime)
      } compactTrailing: {
        Text(shortStatusText(for: context.state))
          .foregroundStyle(Metric.lime)
      } minimal: {
        Image(systemName: "sparkle")
          .foregroundStyle(Metric.lime)
      }
    }
  }
}

private extension FestiCoreFestivalActivityWidget {
  @ViewBuilder
  func lockScreenCard(
    festivalName: String,
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    VStack(spacing: 0) {
      nowPlayingPanel(
        festivalName: festivalName,
        state: state
      )
        .frame(
          maxWidth: .infinity,
          minHeight: 108,
          maxHeight: 108
        )
        .background(Metric.lime)
      nextPanel(
        state: state,
        isStale: isStale
      )
        .frame(
          maxWidth: .infinity,
          minHeight: 48,
          maxHeight: 48
        )
        .background(Metric.black)
    }
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(
      cornerRadius: 24,
      style: .continuous
    ))
    .environment(
      \.colorScheme,
      .dark
    )
  }

  @ViewBuilder
  func nowPlayingPanel(
    festivalName: String,
    state: FestiCoreFestivalActivityAttributes.ContentState
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: 3
    ) {
      HStack(alignment: .firstTextBaseline) {
        Text("NOW PLAYING")
          .font(WidgetFont.pretendardBold(10))
          .tracking(1)
        Spacer(minLength: 4)
        if state.pinnedFlag != nil || state.crewSummary != nil {
          Image(systemName: "star.fill")
            .font(WidgetFont.pretendardBold(10))
          Text(state.crewSummary?.name ?? "내 깃발")
            .font(WidgetFont.pretendardMedium(10))
            .lineLimit(1)
        }
      }
      Text(state.nowStages.first?.stageId ?? festivalName)
        .font(WidgetFont.pretendardMedium(11))
        .lineLimit(1)
      Text(headline(
        for: state,
        isStale: false
      ))
        .font(WidgetFont.bagel(34))
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
    .foregroundStyle(Metric.black)
    .padding(
      .horizontal,
      14
    )
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }

  @ViewBuilder
  func nextPanel(
    state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> some View {
    HStack(
      alignment: .center,
      spacing: 8
    ) {
      VStack(
        alignment: .leading,
        spacing: 2
      ) {
        Text(isStale ? "정보 확인 필요" : "다음 내 일정")
          .font(WidgetFont.pretendardMedium(10))
          .foregroundStyle(.white.opacity(0.7))
        nextSchedule(for: state)
      }
      Spacer(minLength: 4)
      if !isStale, let next = state.nextMine,
         let start = performanceDate(next.startsAt) {
        Text(
          start,
          style: .relative
        )
          .font(WidgetFont.bagel(24))
          .minimumScaleFactor(0.65)
          .lineLimit(1)
          .foregroundStyle(Metric.lime)
      }
    }
    .padding(
      .horizontal,
      14
    )
  }

  @ViewBuilder
  func nextSchedule(
    for state: FestiCoreFestivalActivityAttributes.ContentState
  ) -> some View {
    if let next = state.nextMine {
      Text("\(next.artist) · \(next.stageId)")
        .font(WidgetFont.pretendardMedium(11))
        .foregroundStyle(.white)
        .lineLimit(1)
    } else {
      Text(state.phase == .finished ? "축제가 종료됐어요" : "저장한 공연이 없어요")
        .font(WidgetFont.pretendardMedium(11))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
  }

  func headline(
    for state: FestiCoreFestivalActivityAttributes.ContentState,
    isStale: Bool
  ) -> String {
    if isStale { return "정보를 확인해 주세요" }
    if let current = state.nowStages.first { return current.artist }
    switch state.phase {
    case .upcoming: return "곧 시작해요"
    case .ongoing: return "공연 진행 중"
    case .finished: return "공연 종료"
    }
  }

  func shortStatusText(for state: FestiCoreFestivalActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .upcoming: return "예정"
    case .ongoing: return "진행"
    case .finished: return "종료"
    }
  }

  func performanceDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}

private enum Metric {
  static let lime = Color(
    red: 0.776,
    green: 1,
    blue: 0.204
  )
  static let black = Color(
    red: 0.067,
    green: 0.067,
    blue: 0.075
  )
}

private enum WidgetFont {
  private static let registered: Void = {
    for name in ["BagelFatOne-Regular", "PretendardVariable"] {
      guard let url = Bundle.main.url(
        forResource: name,
        withExtension: "ttf",
        subdirectory: "Resources/Fonts"
      ) ?? Bundle.main.url(
        forResource: name,
        withExtension: "ttf"
      ) else {
        continue
      }
      CTFontManagerRegisterFontsForURL(
        url as CFURL,
        .process,
        nil
      )
    }
  }()

  static func bagel(_ size: CGFloat) -> Font {
    _ = registered
    return .custom(
      "BagelFatOne-Regular",
      fixedSize: size
    )
  }

  static func pretendardBold(_ size: CGFloat) -> Font {
    _ = registered
    return .custom(
      "PretendardVariable-Bold",
      fixedSize: size
    )
  }

  static func pretendardMedium(_ size: CGFloat) -> Font {
    _ = registered
    return .custom(
      "PretendardVariable-Medium",
      fixedSize: size
    )
  }
}
