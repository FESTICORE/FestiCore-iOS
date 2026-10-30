import Dependencies
import FestiCoreLiveActivity
import Foundation

public struct FestivalLiveActivityRecord: Equatable, Sendable {
  let id: String
  let festivalID: String
  let phase: FestivalLiveActivitySchedule.Phase
  let startDate: Date
  let endDate: Date?
}

struct FestivalLiveActivityClient: Sendable {
  var activities: @Sendable () async -> [FestivalLiveActivityRecord]
  var changes: @Sendable () -> AsyncStream<Void>
  var start: @Sendable (String, String, Date, Date, FestivalLiveActivitySchedule.Phase) async throws -> String
  var update: @Sendable (String, FestivalLiveActivitySchedule.Phase, Date, Date) async -> Void
  var finish: @Sendable (String, Date) async -> Void
  var end: @Sendable (String) async -> Void
}

extension FestivalLiveActivityClient: DependencyKey {
  static let testValue = Self(
    activities: { [] },
    changes: { AsyncStream { $0.finish() } },
    start: { _, _, _, _, _ in "test-activity" },
    update: { _, _, _, _ in },
    finish: { _, _ in },
    end: { _ in }
  )

  static let liveValue = Self(
    activities: {
      FestiCoreFestivalLiveActivity.activities().map {
        FestivalLiveActivityRecord(
          id: $0.id,
          festivalID: $0.festivalID,
          phase: .init(rawValue: $0.phase.rawValue) ?? .upcoming,
          startDate: $0.startDate,
          endDate: $0.endDate
        )
      }
    },
    changes: { FestiCoreFestivalLiveActivity.activityChanges() },
    start: { id, name, startDate, endDate, phase in
      try FestiCoreFestivalLiveActivity.start(
        festivalID: id,
        festivalName: name,
        startDate: startDate,
        phase: .init(rawValue: phase.rawValue) ?? .upcoming,
        endDate: endDate
      )
    },
    update: { id, phase, startDate, endDate in
      await FestiCoreFestivalLiveActivity.update(
        id: id,
        phase: .init(rawValue: phase.rawValue) ?? .upcoming,
        startDate: startDate,
        endDate: endDate
      )
    },
    finish: { id, startDate in
      await FestiCoreFestivalLiveActivity.endFinished(id: id, startDate: startDate)
    },
    end: { id in await FestiCoreFestivalLiveActivity.end(id: id) }
  )
}

extension DependencyValues {
  var festivalLiveActivityClient: FestivalLiveActivityClient {
    get { self[FestivalLiveActivityClient.self] }
    set { self[FestivalLiveActivityClient.self] = newValue }
  }
}
