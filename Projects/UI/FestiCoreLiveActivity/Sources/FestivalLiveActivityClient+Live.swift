import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalLiveActivityClient: DependencyKey {
  public static let liveValue = Self(
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
        endDate: endDate,
        remoteUpdates: true
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
