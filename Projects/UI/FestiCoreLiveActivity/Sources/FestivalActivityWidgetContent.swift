import FestivalDomainInterface
import Foundation

/// 서버 시작 payload에 일정이 없을 때 앱과 공유한 저장 일정으로 Live Activity를 보완한다.
public enum FestivalActivityWidgetContent {
  /// payload의 다음 내 일정을 쓰고, 앱이 확인하지 않은 빈 값일 때만 공유 저장 일정으로 채운다.
  public static func resolvedNextMine(
    state: FestiCoreFestivalActivityAttributes.ContentState,
    snapshot: @autoclosure () -> FestivalWidgetSnapshot?,
    festivalID: String,
    now: Date
  ) -> FestiCoreFestivalActivityAttributes.ContentState.NextMine? {
    if let nextMine = state.nextMine { return nextMine }
    // 앱이 내 일정이 비었다고 확인했으면 오래된 스냅샷으로 되살리지 않는다.
    guard state.isNextMineConfirmed != true else { return nil }
    return Self.nextMine(
      snapshot: snapshot(),
      festivalID: festivalID,
      now: now
    )
  }

  public static func nextMine(
    snapshot: FestivalWidgetSnapshot?,
    festivalID: String,
    now: Date
  ) -> FestiCoreFestivalActivityAttributes.ContentState.NextMine? {
    guard let snapshot,
          snapshot.festivalID == festivalID,
          snapshot.hasPack else { return nil }
    guard let performance = snapshot.performances
      .filter({ $0.isSaved && $0.startsAt > now })
      .min(by: { $0.startsAt < $1.startsAt }) else { return nil }

    return FestiCoreFestivalActivityAttributes.ContentState.NextMine(
      setId: performance.id,
      stageId: "",
      stageName: performance.stageName,
      artist: performance.artist,
      startsAt: ISO8601DateFormatter().string(from: performance.startsAt)
    )
  }

  /// Figma Live Activity 공연 전·종료 후 상태. 공연 중이거나 판단할 행사일·공연이 없으면 만들지 않는다.
  public struct DayStatus: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
      /// 오늘 개장 전. `{축제} · DAY 1`, `15:00 개장`
      case beforeOpening(opensAt: Date)
      /// 오늘 공연이 모두 끝남. `{축제} · DAY 1 끝`, `오늘 끝!`
      case finished(next: NextOpening?)
    }

    /// 축제 몇째 날인지(1부터)
    public let day: Int
    public let phase: Phase

    public init(
      day: Int,
      phase: Phase
    ) {
      self.day = day
      self.phase = phase
    }

    /// 오늘 공연이 모두 끝났으면 true
    public var isFinished: Bool {
      if case .finished = phase { return true }
      return false
    }

    /// 오늘 개장 시각. 개장 전에만 있다.
    public var opensAt: Date? {
      if case let .beforeOpening(opensAt) = phase { return opensAt }
      return nil
    }

    /// 다음 행사일 개장. 종료 후에만 있다.
    public var next: NextOpening? {
      if case let .finished(next) = phase { return next }
      return nil
    }
  }

  /// 다음 행사일 개장. 내일이면 `내일 15:00 개장`으로 보인다.
  public struct NextOpening: Equatable, Sendable {
    public let day: Int
    public let date: Date
    public let opensAt: Date
    public let isTomorrow: Bool
  }

  /// 앱과 공유한 행사일·공연으로 오늘의 개장 전·종료 후 상태를 정한다.
  public static func dayStatus(
    state: FestiCoreFestivalActivityAttributes.ContentState,
    snapshot: FestivalWidgetSnapshot?,
    festivalID: String,
    now: Date,
    calendar: Calendar
  ) -> DayStatus? {
    guard state.nowStages.isEmpty,
          let snapshot,
          snapshot.festivalID == festivalID,
          snapshot.hasPack else { return nil }
    // 자정을 넘겨 이어지는 전날 공연도 공연 중으로 본다.
    guard !snapshot.performances.contains(where: { $0.startsAt <= now && now < $0.endsAt }) else { return nil }
    let days = (snapshot.days ?? []).sorted { $0.date < $1.date }
    guard let index = days.firstIndex(where: { calendar.isDate(
      $0.date,
      inSameDayAs: now
    ) }) else { return nil }
    let today = snapshot.performances.filter { calendar.isDate(
      $0.startsAt,
      inSameDayAs: days[index].date
    ) }
    if let opensAt = days[index].opensAt ?? today.map(\.startsAt).min(), now < opensAt {
      return DayStatus(
        day: index + 1,
        phase: .beforeOpening(opensAt: opensAt)
      )
    }
    guard let lastEnd = today.map(\.endsAt).max(), now >= lastEnd else { return nil }
    let next = nextOpening(
      days: days,
      after: index,
      now: now,
      calendar: calendar
    )
    return DayStatus(
      day: index + 1,
      phase: .finished(next: next)
    )
  }

  /// 첫 행사일 전 제목에 쓸 첫날 개장. 예: `내일 15:00 개장`.
  public static func firstOpening(
    snapshot: FestivalWidgetSnapshot?,
    festivalID: String,
    now: Date,
    calendar: Calendar
  ) -> NextOpening? {
    guard let snapshot,
          snapshot.festivalID == festivalID,
          snapshot.hasPack else { return nil }
    let days = (snapshot.days ?? []).sorted { $0.date < $1.date }
    guard let first = days.first, calendar.startOfDay(for: now) < first.date else { return nil }
    return nextOpening(
      days: days,
      after: -1,
      now: now,
      calendar: calendar
    )
  }

  /// Figma Widget·Live Activity 종료 1시간 전 귀가 안내. 12시간 안에 떠날 마지막 셔틀·막차만 담는다.
  public struct HomeRide: Equatable, Sendable {
    public let shuttleAt: Date?
    public let shuttleStopName: String?
    public let trainAt: Date?
    public let trainStationName: String?
    /// 남은 시간을 셀 시각. 셔틀이 있으면 셔틀, 없으면 막차.
    public let target: Date
    /// `마지막 셔틀`, 셔틀이 없으면 `막차`
    public let label: String
    /// `정문 23:40 · 막차 23:52`. 셔틀만 있으면 `정문 23:40`, 막차만 있으면 `23:52 킨텍스역`.
    public let detail: String
    /// Figma Widget Small Bar: `셔틀 23:40`, 셔틀이 없으면 `막차 23:52`.
    public let shortText: String
    /// Figma Lock Screen 사각형 아래 줄: `정문 · 막차 23:52`. 막차만 있으면 `detail`과 같다.
    public let accessoryDetail: String
  }

  /// 앱과 공유한 마지막 셔틀·막차 중 아직 떠나지 않았고 12시간 안에 떠날 편으로 귀가 안내를 만든다. 자정을 넘겨 떠나는 편도 담는다.
  /// 시각은 `calendar`의 시간대로 쓴다. 둘 다 없으면 nil.
  public static func homeRide(
    snapshot: FestivalWidgetSnapshot?,
    festivalID: String,
    now: Date,
    calendar: Calendar
  ) -> HomeRide? {
    guard let snapshot, snapshot.festivalID == festivalID else { return nil }
    let isUpcoming = { (date: Date) -> Bool in
      return date > now && date.timeIntervalSince(now) <= 12 * 3600
    }
    let shuttleAt = snapshot.lastShuttleAt.flatMap { isUpcoming($0) ? $0 : nil }
    let trainAt = snapshot.lastTrainAt.flatMap { isUpcoming($0) ? $0 : nil }
    guard let target = shuttleAt ?? trainAt else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "HH:mm"
    let stopName = nonempty(snapshot.shuttleStopName)
    let stationName = nonempty(snapshot.trainStationName)
    let detail: String
    let accessoryDetail: String
    if let shuttleAt {
      let shuttle = [stopName, formatter.string(from: shuttleAt)]
        .compactMap { $0 }
        .joined(separator: " ")
      detail = trainAt.map { "\(shuttle) · 막차 \(formatter.string(from: $0))" } ?? shuttle
      let places = [stopName, trainAt.map { "막차 \(formatter.string(from: $0))" }].compactMap { $0 }
      accessoryDetail = places.isEmpty ? formatter.string(from: shuttleAt) : places.joined(separator: " · ")
    } else {
      detail = [formatter.string(from: target), stationName]
        .compactMap { $0 }
        .joined(separator: " ")
      accessoryDetail = detail
    }
    return HomeRide(
      shuttleAt: shuttleAt,
      shuttleStopName: stopName,
      trainAt: trainAt,
      trainStationName: stationName,
      target: target,
      label: shuttleAt == nil ? "막차" : "마지막 셔틀",
      detail: detail,
      shortText: "\(shuttleAt == nil ? "막차" : "셔틀") \(formatter.string(from: target))",
      accessoryDetail: accessoryDetail
    )
  }

  /// 고정 깃발 줄. 예: "호락호락 · 슬램", 쉬는 중이면 "호락호락 · 쉬는 중".
  public static func pinnedFlagText(
    _ flag: FestiCoreFestivalActivityAttributes.ContentState.PinnedFlag?
  ) -> String? {
    guard let flag else { return nil }
    let name = flag.name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let status = flag.status == .resting ? "쉬는 중" : flag.activity.flatMap(activityTitle)
    return [name?.isEmpty == false ? name : "내 깃발", status]
      .compactMap { $0 }
      .joined(separator: " · ")
  }

  /// 크루 줄. 예: "크루 4명 · 3명 현장".
  public static func crewText(
    _ crew: FestiCoreFestivalActivityAttributes.ContentState.CrewSummary?
  ) -> String? {
    guard let crew else { return nil }
    let total = "크루 \(crew.memberCount)명"
    guard crew.hereCount > 0 else { return total }
    return "\(total) · \(crew.hereCount)명 현장"
  }

  static func nextOpening(
    days: [FestivalWidgetSnapshot.Day],
    after index: Int,
    now: Date,
    calendar: Calendar
  ) -> NextOpening? {
    let nextIndex = index + 1
    guard days.indices.contains(nextIndex), let opensAt = days[nextIndex].opensAt else { return nil }
    let tomorrow = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: now)
    )
    let isTomorrow = tomorrow.map { calendar.isDate(
      days[nextIndex].date,
      inSameDayAs: $0
    ) } ?? false
    return NextOpening(
      day: nextIndex + 1,
      date: days[nextIndex].date,
      opensAt: opensAt,
      isTomorrow: isTomorrow
    )
  }

  static func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }

  static func activityTitle(_ raw: String) -> String? {
    switch raw {
    case "slam": return "슬램"
    case "sing": return "떼창"
    case "train": return "기차놀이"
    case "calm": return "차분"
    default: return nil
    }
  }
}
