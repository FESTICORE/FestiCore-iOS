import Foundation

/// Live Activity를 새로 시작할 때 전달할 축제와 일정 정보.
public struct FestivalLiveActivityStartRequest: Sendable {
  public let festivalID: String
  public let festivalName: String
  public let startDate: Date
  public let endDate: Date
  public let phase: FestivalLiveActivityPhase
  public let scheduledStart: Date?

  public init(
    festivalID: String,
    festivalName: String,
    startDate: Date,
    endDate: Date,
    phase: FestivalLiveActivityPhase,
    scheduledStart: Date?
  ) {
    self.festivalID = festivalID
    self.festivalName = festivalName
    self.startDate = startDate
    self.endDate = endDate
    self.phase = phase
    self.scheduledStart = scheduledStart
  }
}
