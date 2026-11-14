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
    // Figma Widget 공연 전: 개장 시각에 `15:00 개장`에서 공연 전 상태로 넘어간다.
    for day in snapshot?.days ?? [] {
      if let opensAt = day.opensAt, opensAt > now, opensAt < horizon { dates.insert(opensAt) }
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
    // 마지막 날 종료 후는 다음 페스티벌을 고르도록 축제 목록(S00)을 연다.
    if let snapshot, snapshot.hasPack, !isFestivalOver,
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

  /// 마지막 날 공연까지 끝났으면 true. 남은 공연이 없을 때의 종료 후 상태다.
  var isFestivalOver: Bool {
    return phase == .finished && !performances.contains { $0.startsAt > date }
  }

  /// 다음 축제 일자의 개장 안내(Figma Widget 종료 후 `내일 DAY 2 · 15:00 개장`).
  struct UpcomingOpening {
    let number: Int
    /// `내일` 또는 `M/d(E)`
    let dayWord: String
    let opensAt: Date

    var time: String { return opensAt.formatted(.time) }
  }

  /// 팩 일자(날짜순). 이전 버전 스냅샷에는 없다.
  var festivalDays: [FestivalWidgetSnapshot.Day] {
    return (snapshot?.days ?? []).sorted { $0.date < $1.date }
  }

  /// 오늘이 축제 몇째 날인지(1부터). 축제 일자가 아니면 nil.
  var todayNumber: Int? {
    guard let index = festivalDays.firstIndex(where: {
      AppDateFormat.calendar.isDate(
        $0.date,
        inSameDayAs: date
      )
    }) else { return nil }
    return index + 1
  }

  /// 공연 전 상태이고 오늘 개장 전이면 오늘 개장 시각(Figma Widget 공연 전 `OPEN 15:00`).
  var openingToday: Date? {
    guard phase == .before, let number = todayNumber,
          let opensAt = festivalDays[number - 1].opensAt, date < opensAt else { return nil }
    return opensAt
  }

  /// 오늘 공연이 끝난 뒤 다음 축제 일자의 개장 시각.
  var upcomingOpening: UpcomingOpening? {
    guard phase == .finished, !isFestivalOver else { return nil }
    let calendar = AppDateFormat.calendar
    let startOfToday = calendar.startOfDay(for: date)
    guard let index = festivalDays.firstIndex(where: { $0.date > startOfToday }),
          let opensAt = festivalDays[index].opensAt else { return nil }
    let tomorrow = calendar.date(
      byAdding: .day,
      value: 1,
      to: startOfToday
    )
    let isTomorrow = tomorrow.map { calendar.isDate(
      festivalDays[index].date,
      inSameDayAs: $0
    ) } ?? false
    return UpcomingOpening(
      number: index + 1,
      dayWord: isTomorrow ? "내일" : festivalDays[index].date.formatted(.festivalDay),
      opensAt: opensAt
    )
  }

  /// Figma Widget Small 히어로. 공연 전 개장 전에는 `오늘 개장!`.
  var smallHeadline: String {
    if phase == .noPack { return "팩을\n받아요" }
    if openingToday != nil { return "오늘\n개장!" }
    return headline
  }

  var headline: String {
    switch phase {
    case .unavailable: return "정보를 불러오지 못했어요"
    case .noPack: return "페스티벌 고르기"
    case .goingHome: return "귀가 준비!"
    case .finished:
      guard isFestivalOver, let snapshot else { return "오늘 끝!" }
      return "\(snapshot.festivalName) 끝"
    case .playing: return current?.artist ?? "다음 공연 준비 중"
    case .before:
      if let openingToday { return "\(openingToday.formatted(.time)) 개장" }
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
    case .finished:
      if isFestivalOver { return "다음 페스티벌 보기" }
      guard let next else { return "다음 페스티벌에서 만나요" }
      // Figma Widget 종료 후: 다음 날 일정은 `내일 첫 내 일정`.
      return isTomorrow(next.startsAt) ? "내일 첫 내 일정" : "다음 내 일정"
    case .before: return next == nil ? "내 일정이 없어요" : "첫 내 일정"
    case .playing: return next == nil ? "내 일정이 없어요" : "다음 내 일정"
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
    // 공연 중 머리말은 NEXT라 이미 시작한 공연은 빼고 앞으로 볼 공연만 보인다.
    let saved = candidates.filter { performance in
      guard performance.isSaved else { return false }
      return phase == .playing ? performance.startsAt > date : performance.endsAt > date
    }
    return Array(saved.prefix(4))
  }


  var scheduleHeading: String {
    if phase == .unavailable { return "정보 확인 필요" }
    // Figma Widget Large: 공연 중은 NEXT, 다음 날 일정은 TOMORROW로 묶는다.
    if phase == .playing { return "NEXT" }
    guard phase == .finished, let next else { return "TODAY · 내 일정" }
    if let tomorrow = AppDateFormat.calendar.date(
      byAdding: .day,
      value: 1,
      to: date
    ), AppDateFormat.calendar.isDate(
      next.startsAt,
      inSameDayAs: tomorrow
    ) {
      return "TOMORROW · 내 일정"
    }
    return "\(next.startsAt.formatted(.festivalDay)) · 내 일정"
  }

  /// Figma Widget Small 칩: 공연 중은 `NOW · 무대`, 개장 전은 `OPEN 15:00`, 그 밖은 상태 머리말.
  var chipTitle: String {
    if phase == .playing, let current { return "NOW · \(current.stageName)" }
    if let openingToday { return "OPEN \(openingToday.formatted(.time))" }
    return eyebrow
  }

  func isTomorrow(_ value: Date) -> Bool {
    guard let tomorrow = AppDateFormat.calendar.date(
      byAdding: .day,
      value: 1,
      to: date
    ) else { return false }
    return AppDateFormat.calendar.isDate(
      value,
      inSameDayAs: tomorrow
    )
  }

  /// Figma Widget Medium·Large 상단 줄.
  var topLine: String {
    switch phase {
    case .unavailable, .noPack: return "FESTICORE"
    case .playing:
      guard let current else { return eyebrow }
      return "\(eyebrow) · \(current.stageName) · \(current.startsAt.formatted(.time))"
    case .goingHome: return "\(eyebrow) · 종료 1시간 전"
    case .before:
      let name = snapshot?.festivalName ?? "FESTICORE"
      // Figma Widget Medium·Large 공연 전: `{축제} · DAY 1 · 11/21(토)`
      guard let todayNumber else { return name }
      return "\(name) · DAY \(todayNumber) · \(date.formatted(.festivalDay))"
    case .finished:
      let name = snapshot?.festivalName ?? "FESTICORE"
      // Figma Widget Medium·Large 종료 후: `{축제} · DAY 1 끝`
      guard let todayNumber else { return name }
      return "\(name) · DAY \(todayNumber) 끝"
    }
  }

  /// Figma Widget Medium 서브 줄(Bagel 14).
  var subline: String? {
    switch phase {
    case .noPack: return "팩을 받으면 여기에 무대가 떠요"
    case .playing:
      guard let current else { return nil }
      guard let following = performances.first(where: {
        $0.stageName == current.stageName && $0.startsAt >= current.endsAt
      }) else {
        return "@\(current.stageName)"
      }
      return "@\(current.stageName)  \(following.artist)"
    case .before:
      guard let first = performances.first(where: { $0.startsAt > date }) else { return nil }
      return "@\(first.stageName)  첫 공연 \(first.artist) \(first.startsAt.formatted(.time))"
    case .goingHome:
      guard let last = today.max(by: { $0.endsAt < $1.endsAt }) else { return nil }
      return "@\(last.stageName)  마지막 무대 \(last.artist)"
    case .finished:
      // Figma Widget Medium 종료 후: `내일 DAY 2 · 15:00 개장`
      guard let upcomingOpening else { return nil }
      return "\(upcomingOpening.dayWord) DAY \(upcomingOpening.number) · \(upcomingOpening.time) 개장"
    case .unavailable: return nil
    }
  }

  /// Figma Widget 하단 바 왼쪽 글자. Medium은 라벨과 내용을 한 줄에 둔다.
  func footerText(for family: WidgetFamily) -> String {
    switch family {
    case .systemSmall:
      if phase == .noPack { return "탭해서 페스티벌 고르기" }
      // Figma Widget Small 종료 후: `DAY 2 · 내일 15:00 개장`
      if let upcomingOpening {
        return "DAY \(upcomingOpening.number) · \(upcomingOpening.dayWord) \(upcomingOpening.time) 개장"
      }
      if phase == .before || phase == .playing, let next { return next.artist }
      return footerTitle
    case .systemLarge:
      switch phase {
      case .noPack: return "탭하면 페스티벌 목록으로 가요"
      case .finished where !isFestivalOver: return "조심히 들어가요 · 팩은 오프라인으로도 볼 수 있어요"
      case .before where next == nil, .playing where next == nil: return "내 일정을 넣으면 남은 시간을 알려 드려요"
      case .unavailable: return footerTitle
      default: return "\(footerTitle)  \(footerDetail)"
      }
    default:
      if phase == .noPack { return "탭해서 시작하기" }
      if phase == .unavailable { return footerTitle }
      return "\(footerTitle)  \(footerDetail)"
    }
  }

  /// Figma Widget Large 하단 바 아이콘.
  var largeFooterIcon: ImageAsset? {
    switch phase {
    case .noPack: return .chevronRight16
    case .finished: return isFestivalOver ? nil : .circleCheck16
    case .goingHome: return .route16
    case .before, .playing: return next == nil ? .plus16 : nil
    case .unavailable: return nil
    }
  }

  /// Figma Widget 종료 후 Small·Medium 하단 바는 남은 시간을 보이지 않는다.
  var showsBarCountdown: Bool {
    return phase != .finished
  }

  var rectangularLabel: String {
    if phase == .noPack { return "FESTICORE" }
    // Figma Lock Screen 종료 후: `{축제} DAY 1`
    if phase == .finished, !isFestivalOver, let todayNumber, let snapshot {
      return "\(snapshot.festivalName) DAY \(todayNumber)"
    }
    if phase == .playing, next == nil, let current { return "지금 \(current.stageName)" }
    return footerTitle
  }

  /// Figma Lock Screen 인라인 공연 전 `개장 15:00 · 첫 일정 15:30`, 종료 후 `오늘 공연 끝 · 내일 15:00 개장`.
  var inlineOverride: String? {
    if let openingToday {
      let opening = "개장 \(openingToday.formatted(.time))"
      // 첫 일정은 오늘 저장한 공연만 쓴다. 다른 날 일정을 오늘 첫 일정으로 보이지 않는다.
      guard let first = today.first(where: { $0.isSaved && $0.startsAt > date }) else { return opening }
      return "\(opening) · 첫 일정 \(first.startsAt.formatted(.time))"
    }
    if let upcomingOpening {
      return "오늘 공연 끝 · \(upcomingOpening.dayWord) \(upcomingOpening.time) 개장"
    }
    return nil
  }

  /// Figma Lock Screen 사각형 아래 줄. 종료 후에는 다음 날 개장 시각.
  var rectangularDetail: String {
    if let upcomingOpening { return "\(upcomingOpening.dayWord) \(upcomingOpening.time) 개장" }
    return footerDetail
  }

  /// 잠금화면 원형·사각형 남은 시간. 종료 후에는 `끝`·`오늘 끝!`을 보인다.
  var accessoryTarget: Date? {
    return phase == .finished ? nil : target
  }

  var inlineText: String {
    if phase == .noPack { return "FESTICORE · 팩을 받아 주세요" }
    if phase == .playing, let current { return "\(current.stageName) · \(current.artist) 공연 중" }
    return headline
  }
}

struct FestivalWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var renderingMode
  let entry: FestivalWidgetEntry

  var body: some View {
    switch family {
    case .accessoryInline:
      if let text = entry.inlineOverride {
        Text(text)
      } else if let target = entry.target {
        Text("\(entry.next?.artist ?? entry.footerTitle) ") + Text(
          target,
          style: .relative
        ) + Text(" 후")
      } else {
        Text(entry.inlineText)
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
  /// Figma Widget · Components의 반짝이 별 크기와 위젯 오른쪽 위 기준 여백.
  struct SparkleSpec {
    let size: CGFloat
    let top: CGFloat
    let trailing: CGFloat
  }

  var isSmall: Bool { return family == .systemSmall }
  var isLarge: Bool { return family == .systemLarge }
  var foreground: Color { return renderingMode == .fullColor ? WidgetPalette.black : .primary }
  /// Figma `Static Alpha/Black 60`. 틴트 모드에서는 primary 60%로 낮춘다.
  var assistive: Color {
    return renderingMode == .fullColor ? FestiCoreSemanticColor.staticalphaBlack60.color : Color.primary.opacity(0.6)
  }
  var barTint: Color {
    return renderingMode == .fullColor ? FestiCoreSemanticColor.staticLime.color : .primary
  }

  var sparkles: [SparkleSpec] {
    switch family {
    case .systemSmall:
      return [
        SparkleSpec(
          size: 22,
          top: 12,
          trailing: 14
        ),
        SparkleSpec(
          size: 10,
          top: 40,
          trailing: 40
        )
      ]
    case .systemLarge:
      return [
        SparkleSpec(
          size: 34,
          top: 26,
          trailing: 22
        ),
        SparkleSpec(
          size: 14,
          top: 76,
          trailing: 32
        )
      ]
    default:
      return [
        SparkleSpec(
          size: 26,
          top: 22,
          trailing: 16
        ),
        SparkleSpec(
          size: 12,
          top: 66,
          trailing: 44
        ),
        SparkleSpec(
          size: 9,
          top: 86,
          trailing: 21
        )
      ]
    }
  }

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
      .overlay(alignment: .topTrailing) {
        sparkleLayer
      }
    }
  }

  var sparkleLayer: some View {
    return ZStack(alignment: .topTrailing) {
      ForEach(
        Array(sparkles.enumerated()),
        id: \.offset
      ) { _, spec in
        WidgetSparkle()
          .fill(foreground)
          .frame(
            width: spec.size,
            height: spec.size
          )
          .padding(
            .top,
            spec.top
          )
          .padding(
            .trailing,
            spec.trailing
          )
      }
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  func posterBody() -> some View {
    // Figma: Small 패딩 12/14/12/4·간격 6, Medium 14/12/14/4·간격 2, Large 16/16/16/8·간격 6
    VStack(
      alignment: .leading,
      spacing: isSmall || isLarge ? FestiCoreSpacing.marginM6 : FestiCoreSpacing.marginM2
    ) {
      posterHeader()
      Text(isSmall ? entry.smallHeadline : entry.headline)
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
      if !isSmall, !isLarge, let subline = entry.subline {
        Text(subline)
          .font(WidgetFont.bagel(14))
          .rotationEffect(.degrees(-4))
          .lineLimit(1)
      }
      if isLarge {
        if entry.phase == .noPack {
          Text("팩을 받으면 지금 무대 · 다음 내 일정 ·\n크루가 여기에 떠요.\n오프라인에서도 그대로 보여요.")
            .font(.pretendardFontFamily(
              family: .Medium,
              size: 12
            ))
            .foregroundStyle(assistive)
            .padding(
              .vertical,
              FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
            )
            .padding(
              .horizontal,
              FestiCoreSpacing.marginM2
            )
        } else {
          schedule()
        }
      }
      Spacer(minLength: 0)
    }
    .padding(
      .horizontal,
      isLarge ? FestiCoreSpacing.paddingP16 : isSmall ? FestiCoreSpacing.paddingP12 : FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
    )
    .padding(
      .top,
      isLarge ? FestiCoreSpacing.paddingP16 : isSmall ? FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2 : FestiCoreSpacing.paddingP12
    )
    .padding(
      .bottom,
      isLarge ? FestiCoreSpacing.paddingP8 : FestiCoreSpacing.paddingP4
    )
    .foregroundStyle(foreground)
  }

  @ViewBuilder
  func posterHeader() -> some View {
    if isSmall {
      // Figma Widget Small Chip: Static/Ink r4, 패딩 8/3, Pretendard Bold 10 자간 4%
      Text(entry.chipTitle)
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 10
        ))
        .tracking(0.4)
        .lineLimit(1)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP8
        )
        .padding(
          .vertical,
          3
        )
        .foregroundStyle(renderingMode == .fullColor ? FestiCoreSemanticColor.staticWhite.color : .primary)
        .background(
          renderingMode == .fullColor ? WidgetPalette.black : .clear,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4)
        )
        .padding(
          .trailing,
          FestiCoreSpacing.paddingP24
        )
    } else {
      Text(entry.topLine)
        .font(.pretendardFontFamily(
          family: .Bold,
          size: isLarge ? 10 : 9
        ))
        .tracking(1)
        .lineLimit(1)
        .padding(
          .trailing,
          FestiCoreSpacing.paddingP24 + FestiCoreSpacing.paddingP24
        )
    }
  }

  @ViewBuilder
  func schedule() -> some View {
    // Figma Widget Large List: 패딩 2/14/2/14, 행 간격 10
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM8 + FestiCoreSpacing.marginM2
    ) {
      Text(entry.scheduleHeading)
        .font(.pretendardFontFamily(
          family: .Bold,
          size: 10
        ))
        .tracking(1.2)
        .foregroundStyle(assistive)
      if entry.rows.isEmpty {
        Text(entry.phase == .unavailable ? entry.footerDetail : "내 일정을 담으면 남은 시간을 알려드려요")
          .font(.pretendardFontFamily(
            family: .Medium,
            size: 12
          ))
          .foregroundStyle(assistive)
      } else {
        ForEach(
          entry.rows,
          id: \.id
        ) { performance in
          scheduleRow(performance)
        }
      }
    }
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.marginM2
    )
  }

  func scheduleRow(_ performance: FestivalWidgetSnapshot.Performance) -> some View {
    let isFirst = performance.id == entry.rows.first?.id
    let showsPill = isFirst && performance.id == entry.next?.id && entry.phase != .finished
    return HStack(spacing: FestiCoreSpacing.marginM8) {
      Text(performance.startsAt.formatted(.time))
        .font(.pretendardFontFamily(
          family: .Black,
          size: 11
        ))
        .foregroundStyle(assistive)
        .frame(
          width: 36,
          alignment: .leading
        )
      Text(performance.artist)
        .font(WidgetFont.bagel(isFirst ? 24 : 18))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      if showsPill {
        Spacer(minLength: 0)
        (Text(
          performance.startsAt,
          style: .relative
        ) + Text(" 후"))
          .font(WidgetFont.bagel(12))
          .foregroundStyle(barTint)
          .lineLimit(1)
          .fixedSize()
          .padding(
            .horizontal,
            FestiCoreSpacing.paddingP12
          )
          .padding(
            .vertical,
            5
          )
          .background(
            renderingMode == .fullColor ? WidgetPalette.black : .clear,
            in: Capsule()
          )
      } else {
        Text(performance.stageName)
          .font(.pretendardFontFamily(
            family: .Bold,
            size: 10
          ))
          .foregroundStyle(assistive)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
    }
  }

  @ViewBuilder
  func footer() -> some View {
    // Figma Widget Bar: Small 패딩 12, Medium 14, Large 16·간격 6·아이콘 13
    HStack(spacing: isLarge ? FestiCoreSpacing.marginM6 : FestiCoreSpacing.marginM8) {
      if isLarge, let icon = entry.largeFooterIcon {
        Image(asset: icon)
          .renderingMode(.template)
          .resizable()
          .frame(
            width: 13,
            height: 13
          )
          .accessibilityHidden(true)
      }
      Text(entry.footerText(for: family))
        .font(.pretendardFontFamily(
          family: .Bold,
          size: isLarge ? 12 : 11
        ))
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 0)
      if let target = entry.target, !isLarge, entry.showsBarCountdown {
        (Text(
          target,
          style: .relative
        ) + Text(" 후"))
          .font(WidgetFont.bagel(isSmall ? 15 : 16))
          .foregroundStyle(barTint)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .foregroundStyle(renderingMode == .fullColor ? FestiCoreSemanticColor.staticWhite.color : .primary)
    .padding(
      .horizontal,
      isLarge ? FestiCoreSpacing.paddingP16 : isSmall ? FestiCoreSpacing.paddingP12 : FestiCoreSpacing.paddingP12 + FestiCoreSpacing.marginM2
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
    // Figma Lock Screen Circular: 숫자 Bagel 26 + 단위 Pretendard Bold 9, 간격 2
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: FestiCoreSpacing.marginM2) {
        if let target = entry.accessoryTarget {
          Text(
            target,
            style: .relative
          )
            .font(WidgetFont.bagel(26))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
          circularUnit("후")
        } else if entry.phase == .playing, let current = entry.current {
          Text("NOW")
            .font(WidgetFont.bagel(17))
          circularUnit(current.stageName)
        } else {
          Text(entry.phase == .unavailable ? "!" : entry.phase == .finished ? "끝" : "F")
            .font(WidgetFont.bagel(26))
          circularUnit(circularFallbackUnit)
        }
      }
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP4
      )
    }
  }

  /// Figma Lock Screen 원형 종료 후는 `끝` + `DAY N`.
  var circularFallbackUnit: String {
    if entry.phase == .noPack { return "팩 없음" }
    if entry.phase == .finished, let number = entry.todayNumber { return "DAY \(number)" }
    return "FESTICORE"
  }

  func circularUnit(_ text: String) -> some View {
    return Text(text)
      .font(.pretendardFontFamily(
        family: .Bold,
        size: 9
      ))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .foregroundStyle(.secondary)
  }

  @ViewBuilder
  func countdownLabel() -> some View {
    if let target = entry.accessoryTarget {
      Text(
        target,
        style: .relative
      ) + Text(" 후")
    } else if entry.phase == .noPack {
      Text("팩 없음")
    } else {
      Text(entry.headline)
    }
  }

  @ViewBuilder
  func rectangular() -> some View {
    // Figma Lock Screen Rectangular: 배경 20% r14, 패딩 12/8, 간격 2
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM2
    ) {
      Text(entry.rectangularLabel)
        .font(.pretendardFontFamily(
          family: .SemiBold,
          size: 11
        ))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      countdownLabel()
        .font(WidgetFont.bagel(20))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(entry.rectangularDetail)
        .font(.pretendardFontFamily(
          family: .Medium,
          size: 11
        ))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP12
    )
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP8
    )
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: .leading
    )
    .background(
      AccessoryWidgetBackground()
        .clipShape(RoundedRectangle(cornerRadius: 14))
    )
  }
}

/// Figma Widget `Sparkle`(STAR, 꼭짓점 4개, 안쪽 비율 0.28)을 그대로 그린 장식 별.
struct WidgetSparkle: Shape {
  func path(in rect: CGRect) -> Path {
    let center = CGPoint(
      x: rect.midX,
      y: rect.midY
    )
    let outer = min(
      rect.width,
      rect.height
    ) / 2
    let inner = outer * 0.28
    var path = Path()
    for index in 0..<8 {
      let radius = index.isMultiple(of: 2) ? outer : inner
      let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 4
      let point = CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius
      )
      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }
    path.closeSubpath()
    return path
  }
}
