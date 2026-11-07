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
}
