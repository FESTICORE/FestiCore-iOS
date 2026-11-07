import FestivalDomainInterface
import Foundation

/// 서버 시작 payload에 일정이 없을 때 앱과 공유한 저장 일정으로 Live Activity를 보완한다.
public enum FestivalActivityWidgetContent {
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
