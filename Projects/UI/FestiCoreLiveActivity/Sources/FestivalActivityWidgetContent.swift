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
