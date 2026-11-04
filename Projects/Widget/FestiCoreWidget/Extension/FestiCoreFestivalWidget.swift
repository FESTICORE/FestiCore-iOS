import FestiCoreDesignKit
import FestiCoreLiveActivity
import FestivalDomainInterface
import FestiCoreUtility
import SwiftUI
import WidgetKit

struct FestiCoreFestivalWidget: Widget {
  var body: some WidgetConfiguration {
    return StaticConfiguration(
      kind: "FestiCoreFestivalWidget",
      provider: FestivalWidgetProvider()
    ) { entry in
      FestivalWidgetView(entry: entry)
        .widgetURL(entry.destinationURL)
        .containerBackground(
          FestiCoreSemanticColor.staticLime.color,
          for: .widget
        )
    }
    .configurationDisplayName("페스티벌 내 일정")
    .description("지금 공연과 다음 내 일정을 확인해요.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryInline, .accessoryCircular, .accessoryRectangular
    ])
    .contentMarginsDisabled()
  }
}

struct FestivalWidgetEntry: TimelineEntry {
  let date: Date
  let loadResult: FestivalWidgetStore.LoadResult

  var snapshot: FestivalWidgetSnapshot? {
    guard case let .loaded(snapshot) = loadResult else { return nil }
    return snapshot
  }
}

struct FestivalWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> FestivalWidgetEntry {
    return FestivalWidgetEntry(
      date: .now,
      loadResult: .missing
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (FestivalWidgetEntry) -> Void
  ) {
    return completion(FestivalWidgetEntry(
      date: .now,
      loadResult: FestivalWidgetStore.loadResult()
    ))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<FestivalWidgetEntry>) -> Void
  ) {
    let now = Date.now
    let loadResult = FestivalWidgetStore.loadResult()
    let currentEntry = FestivalWidgetEntry(
      date: now,
      loadResult: loadResult
    )
    if loadResult == .unavailable {
      return completion(Timeline(
        entries: [currentEntry],
        policy: .after(now.addingTimeInterval(15 * 60))
      ))
    }
    let snapshot = currentEntry.snapshot
    let horizon = now.addingTimeInterval(60 * 60)
    // 실제 공연 경계에서 상태를 전환하고 숫자는 시스템 상대 시각으로 갱신한다.
    var dates: Set<Date> = [now]
    if let midnight = AppDateFormat.calendar.date(
      byAdding: .day,
      value: 1,
      to: AppDateFormat.calendar.startOfDay(for: now)
    ), midnight <= horizon {
      dates.insert(midnight)
    }
    for performance in snapshot?.performances ?? [] {
      for boundary in [performance.startsAt, performance.endsAt] where boundary > now && boundary < horizon {
        dates.insert(boundary)
      }
    }
    if let end = currentEntry.today.map(\.endsAt).max() {
      let boundary = end.addingTimeInterval(-3600)
      if boundary > now, boundary < horizon { dates.insert(boundary) }
    }
    if let leaveAt = snapshot?.leaveAt {
      for boundary in [leaveAt.addingTimeInterval(-3600), leaveAt] where boundary > now && boundary < horizon {
        dates.insert(boundary)
      }
    }
    let entries = dates.sorted().map {
      FestivalWidgetEntry(
        date: $0,
        loadResult: loadResult
      )
    }
    return completion(Timeline(
      entries: entries,
      policy: .after(horizon)
    ))
  }
}

extension FestivalWidgetEntry {
  enum Phase {
    case unavailable, noPack, before, playing, goingHome, finished
  }

  var destinationURL: URL? {
    var components = URLComponents()
    components.scheme = "festicore"
    components.host = "festival"
    if let snapshot, snapshot.hasPack,
       let identifier = snapshot.festivalID.addingPercentEncoding(
         withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))
       ) {
      components.percentEncodedPath = "/\(identifier)"
    }
    return components.url
  }

  var performances: [FestivalWidgetSnapshot.Performance] {
    return (snapshot?.performances ?? []).sorted { $0.startsAt < $1.startsAt }
  }

  var today: [FestivalWidgetSnapshot.Performance] {
    return performances.filter {
      ($0.startsAt <= date && date < $0.endsAt) || AppDateFormat.calendar.isDate(
        $0.startsAt,
        inSameDayAs: date
      )
    }
  }

  var current: FestivalWidgetSnapshot.Performance? {
    return performances.first { $0.startsAt <= date && date < $0.endsAt }
  }

  var next: FestivalWidgetSnapshot.Performance? {
    return performances.first { $0.isSaved && $0.startsAt > date }
  }

  var phase: Phase {
    guard loadResult != .unavailable else { return .unavailable }
    guard snapshot?.hasPack == true else { return .noPack }
    if current == nil, let last = today.map(\.endsAt).max(), date >= last { return .finished }
    if today.isEmpty, let last = performances.map(\.endsAt).max(), date >= last { return .finished }
    if let end = today.map(\.endsAt).max(), end > date, end.timeIntervalSince(date) <= 3600 { return .goingHome }
    if current != nil { return .playing }
    if let first = today.first, date >= first.startsAt { return .playing }
    return .before
  }

  var headline: String {
    switch phase {
    case .unavailable: return "정보를 불러오지 못했어요"
    case .noPack: return "페스티벌 고르기"
    case .goingHome: return "귀가 준비!"
    case .finished: return "오늘 끝!"
    case .playing: return current?.artist ?? "다음 공연 준비 중"
    case .before:
      guard let first = performances.first(where: { $0.startsAt > date }) else { return "공연을 기다려요" }
      return "\(first.startsAt.formatted(.time)) 공연 시작"
    }
  }

  var eyebrow: String {
    switch phase {
    case .unavailable, .noPack: return "FESTICORE"
    case .goingHome: return "LAST CALL"
    case .finished: return "SEE YOU"
    case .playing: return "NOW PLAYING"
    case .before: return "UP NEXT"
    }
  }

  var target: Date? {
    if phase == .goingHome { return snapshot?.leaveAt }
    return next?.startsAt
  }

  var footerTitle: String {
    switch phase {
    case .unavailable: return "앱에서 다시 확인해 주세요"
    case .noPack: return "팩을 받으면 시작돼요"
    case .goingHome: return snapshot?.leaveAt == nil ? "공연 종료" : "귀가 시간"
    case .finished: return next == nil ? "다음 페스티벌에서 만나요" : "다음 내 일정"
    case .before, .playing: return next == nil ? "내 일정이 없어요" : "다음 내 일정"
    }
  }

  var footerDetail: String {
    if phase == .unavailable { return "잠시 후 다시 시도할게요" }
    if phase == .noPack { return "앱에서 페스티벌 고르기" }
    if phase == .goingHome {
      return (snapshot?.leaveAt ?? today.map(\.endsAt).max())?.formatted(.time) ?? "귀가 시간을 확인해 주세요"
    }
    if let next { return "\(next.artist) · \(next.stageName) \(next.startsAt.formatted(.time))" }
    if phase == .finished { return "팩은 오프라인으로 볼 수 있어요" }
    if let upcoming = performances.first(where: { $0.startsAt > date }) {
      return "\(upcoming.artist) · \(upcoming.startsAt.formatted(.time))"
    }
    return "앱에서 내 일정을 담아보세요"
  }

  var rows: [FestivalWidgetSnapshot.Performance] {
    let candidates: [FestivalWidgetSnapshot.Performance]
    if phase == .finished, let next {
      candidates = performances.filter { AppDateFormat.calendar.isDate(
        $0.startsAt,
        inSameDayAs: next.startsAt
      ) }
    } else {
      candidates = today
    }
    let saved = candidates.filter { $0.isSaved && $0.endsAt > date }
    return Array(saved.prefix(4))
  }

  var scheduleHeading: String {
    if phase == .unavailable { return "정보 확인 필요" }
    guard phase == .finished, let next else { return "TODAY · 내 일정" }
    return "\(next.startsAt.formatted(.festivalDay)) · 내 일정"
  }
}

struct FestivalWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var renderingMode
  let entry: FestivalWidgetEntry

  var body: some View {
    switch family {
    case .accessoryInline:
      if let target = entry.target {
        Text("\(entry.next?.artist ?? entry.footerTitle) ") + Text(
          target,
          style: .relative
        ) + Text(" 후")
      } else {
        Text(entry.headline)
      }
    case .accessoryCircular:
      circular()
    case .accessoryRectangular:
      rectangular()
    default:
      poster()
    }
  }
}

private extension FestivalWidgetView {
  var isSmall: Bool { return family == .systemSmall }
  var isLarge: Bool { return family == .systemLarge }
  var foreground: Color { return renderingMode == .fullColor ? WidgetPalette.black : .primary }

  @ViewBuilder
  func poster() -> some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        posterBody()
          .frame(
            width: geometry.size.width,
            height: max(
              0,
              geometry.size.height - (isLarge ? 44 : 34)
            ),
            alignment: .topLeading
          )
        footer()
      }
    }
  }

  @ViewBuilder
  func posterBody() -> some View {
    VStack(
      alignment: .leading,
      spacing: isSmall ? FestiCoreSpacing.marginM8 : FestiCoreSpacing.marginM6
    ) {
      posterHeader()
      Text(isSmall && entry.phase == .noPack ? "팩을\n받아요" : entry.headline)
        .font(WidgetFont.bagel(isSmall ? 30 : isLarge ? 44 : 34))
        .widgetAccentable()
        .rotationEffect(.degrees(isSmall || isLarge ? -6 : -4))
        .lineLimit(isSmall ? 2 : 1)
        .minimumScaleFactor(0.65)
        .frame(
          maxWidth: .infinity,
          maxHeight: isSmall ? 72 : isLarge ? 60 : 44,
          alignment: .leading
        )
      if !isSmall {
        if let stage = entry.current?.stageName {
          Text("\(entry.eyebrow) · \(stage)")
            .font(WidgetFont.bagel(14))
            .rotationEffect(.degrees(-4))
            .lineLimit(1)
        } else if entry.phase == .noPack, !isLarge {
          Text("선택하고 이 위젯에 담아보세요")
            .font(.pretendardFontFamily(
              family: .Medium,
              size: 11
            ))
            .lineLimit(1)
        }
      }
      if isLarge {
        if entry.phase == .noPack {
          Text("팩을 받으면 지금 무대 · 다음 내 일정이 보여요.\n오프라인에서도 그대로 보여요.")
            .font(.pretendardFontFamily(
              family: .Medium,
              size: 12
            ))
            .padding(
              .top,
              FestiCoreSpacing.paddingP8
            )
        } else {
          schedule()
        }
      }
      Spacer(minLength: 0)
    }
    .overlay(alignment: .topTrailing) {
      Image(systemName: "sparkle")
        .font(.system(size: isSmall ? 20 : 28))
        .accessibilityHidden(true)
    }
    .padding(
      .horizontal,
      isLarge ? FestiCoreSpacing.paddingP16 : FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
    )
    .padding(
      .vertical,
      isLarge ? FestiCoreSpacing.paddingP16 : FestiCoreSpacing.paddingP12
    )
    .foregroundStyle(foreground)
  }

  @ViewBuilder
  func posterHeader() -> some View {
    if isSmall, entry.phase == .noPack {
      Text("FESTICORE")
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 9
        ))
        .tracking(1)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
        .padding(
          .vertical,
          FestiCoreSpacing.marginM2
        )
        .foregroundStyle(renderingMode == .fullColor ? FestiCoreSemanticColor.staticLime.color : .primary)
        .background(renderingMode == .fullColor ? WidgetPalette.black : .clear)
        .rotationEffect(.degrees(-6))
    } else {
      Text(isSmall ? entry.eyebrow : entry.snapshot?.festivalName ?? "FESTICORE")
        .font(.pretendardFontFamily(
          family: .Bold,
          size: isLarge ? 10 : 9
        ))
        .tracking(1)
        .lineLimit(1)
        .padding(
          .trailing,
          FestiCoreSpacing.paddingP24
        )
    }
  }

  @ViewBuilder
  func schedule() -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM8 + FestiCoreSpacing.marginM2
    ) {
      Text(entry.scheduleHeading)
        .font(.pretendardFontFamily(
          family: .Medium,
          size: 9
        ))
        .tracking(1)
      if entry.rows.isEmpty {
        Text(entry.phase == .unavailable ? entry.footerDetail : entry.phase == .noPack ? "팩을 받으면 지금 무대 · 다음 내 일정이 보여요" : "내 일정을 담으면 남은 시간을 알려드려요")
          .font(.pretendardFontFamily(
            family: .Medium,
            size: 12
          ))
      } else {
        ForEach(
          entry.rows,
          id: \.id
        ) { performance in
          HStack(
            alignment: .firstTextBaseline,
            spacing: FestiCoreSpacing.marginM8
          ) {
            Text(performance.startsAt.formatted(.time))
              .font(.pretendardFontFamily(
                family: .Medium,
                size: 10
              ))
            Text(performance.artist)
              .font(WidgetFont.bagel(performance.id == entry.rows.first?.id ? 24 : 18))
              .lineLimit(1)
              .minimumScaleFactor(0.7)
            Text(performance.stageName)
              .font(.pretendardFontFamily(
                family: .Medium,
                size: 9
              ))
              .lineLimit(1)
            Spacer(minLength: 0)
          }
        }
      }
    }
    .padding(
      .top,
      FestiCoreSpacing.paddingP8 + FestiCoreSpacing.marginM2
    )
  }

  @ViewBuilder
  func footer() -> some View {
    HStack(spacing: FestiCoreSpacing.marginM8) {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.marginM2
      ) {
        Text(entry.phase == .noPack ? (isSmall ? "탭해서 페스티벌 고르기" : isLarge ? "탭하면 페스티벌 목록으로 가요" : "탭해서 시작하기") : entry.footerTitle)
          .font(.pretendardFontFamily(
            family: .Bold,
            size: isLarge ? 12 : 11
          ))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if !isSmall, entry.phase != .noPack {
          Text(entry.footerDetail)
            .font(.pretendardFontFamily(
              family: .Bold,
              size: 11
            ))
            .lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      if let target = entry.target, !isLarge {
        (Text(
          target,
          style: .relative
        ) + Text(" 후"))
          .font(WidgetFont.bagel(isSmall ? 15 : 16))
          .foregroundStyle(renderingMode == .fullColor ? FestiCoreSemanticColor.staticLime.color : .primary)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .foregroundStyle(renderingMode == .fullColor ? FestiCoreSemanticColor.staticWhite.color : .primary)
    .padding(
      .horizontal,
      isSmall ? FestiCoreSpacing.paddingP8 + FestiCoreSpacing.marginM2 : FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
    )
    .frame(height: isLarge ? 44 : 34)
    .fixedSize(
      horizontal: false,
      vertical: true
    )
    .background(renderingMode == .fullColor ? WidgetPalette.black : .clear)
  }

  @ViewBuilder
  func circular() -> some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        if let target = entry.target {
          Text(
            target,
            style: .relative
          )
            .font(WidgetFont.bagel(22))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
          Text("후")
            .font(.pretendardFontFamily(
              family: .Medium,
              size: 9
            ))
        } else {
          Text(entry.phase == .unavailable ? "!" : entry.phase == .finished ? "끝" : "F")
            .font(WidgetFont.bagel(25))
          Text("FESTICORE")
            .font(.pretendardFontFamily(
              family: .Medium,
              size: 8
            ))
        }
      }
    }
  }

  @ViewBuilder
  func countdownLabel() -> some View {
    if let target = entry.target {
      Text(
        target,
        style: .relative
      ) + Text(" 후")
    } else {
      Text(entry.headline)
    }
  }

  @ViewBuilder
  func rectangular() -> some View {
    VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.marginM2
      ) {
      Text(entry.footerTitle)
        .font(.pretendardFontFamily(
          family: .Medium,
          size: 10
        ))
      countdownLabel()
        .font(WidgetFont.bagel(20))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(entry.footerDetail)
        .font(.pretendardFontFamily(
          family: .Medium,
          size: 10
        ))
        .lineLimit(1)
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }
}
