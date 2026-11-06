import Foundation

/// 종료 상태로 바꿀 Live Activity와 축제 시작 시각.
public struct FestivalLiveActivityFinishRequest: Sendable {
  public let activityID: String
  public let startDate: Date

  public init(
    activityID: String,
    startDate: Date
  ) {
    self.activityID = activityID
    self.startDate = startDate
  }
}
