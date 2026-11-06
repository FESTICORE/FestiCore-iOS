import Foundation

/// 기존 Live Activity에 반영할 최신 축제 상태.
public struct FestivalLiveActivityUpdateRequest: Sendable {
  public let activityID: String
  public let phase: FestivalLiveActivityPhase
  public let startDate: Date
  public let endDate: Date
  public let pack: FestivalPackDocument?
  public let savedSetIDs: Set<String>

  public init(
    activityID: String,
    phase: FestivalLiveActivityPhase,
    startDate: Date,
    endDate: Date,
    pack: FestivalPackDocument?,
    savedSetIDs: Set<String>
  ) {
    self.activityID = activityID
    self.phase = phase
    self.startDate = startDate
    self.endDate = endDate
    self.pack = pack
    self.savedSetIDs = savedSetIDs
  }
}
