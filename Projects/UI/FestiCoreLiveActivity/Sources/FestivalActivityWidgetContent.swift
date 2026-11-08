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
