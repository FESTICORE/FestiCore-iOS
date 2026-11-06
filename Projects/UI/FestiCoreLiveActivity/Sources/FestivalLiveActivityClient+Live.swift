import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalLiveActivityClient: @retroactive DependencyKey {
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
    start: { request in
      try FestiCoreFestivalLiveActivity.start(
        festivalID: request.festivalID,
        festivalName: request.festivalName,
        startDate: request.startDate,
        phase: .init(rawValue: request.phase.rawValue) ?? .upcoming,
        endDate: request.endDate,
        remoteUpdates: true,
        scheduledStart: request.scheduledStart
      )
    },
    update: { request in
      let presentation = FestivalActivityPresentation.from(
        pack: request.pack,
        savedSetIDs: request.savedSetIDs,
        now: Date()
      )
      await FestiCoreFestivalLiveActivity.update(
        id: request.activityID,
        phase: .init(rawValue: request.phase.rawValue) ?? .upcoming,
        startDate: request.startDate,
        endDate: request.endDate,
        nowStages: request.pack == nil ? nil : presentation.nowStages,
        nextMine: presentation.nextMine
      )
    },
    finish: { request in
      await FestiCoreFestivalLiveActivity.endFinished(
        id: request.activityID,
        startDate: request.startDate
      )
    },
    end: { id in await FestiCoreFestivalLiveActivity.end(id: id) }
  )
}

struct FestivalActivityPresentation {
  typealias State = FestiCoreFestivalActivityAttributes.ContentState

  let nowStages: [State.NowStage]
  let nextMine: State.NextMine?

  static func from(
    pack: FestivalPackDocument?,
    savedSetIDs: Set<String>,
    now: Date
  ) -> Self {
    let performances = pack?.performances ?? []
    let nowStages = performances.compactMap { performance -> State.NowStage? in
      guard let startsAt = performance.startsAt,
            let endsAt = performance.endsAt,
            let start = parse(startsAt), let end = parse(endsAt),
            start <= now, now < end else { return nil }
      return State.NowStage(
        setId: performance.id,
        stageId: performance.stageId ?? "",
        stageName: stageName(
          for: performance,
          in: pack
        ),
        artist: performance.artist ?? "공연",
        startsAt: startsAt,
        endsAt: endsAt
      )
    }
    let nextPerformances = performances
      .compactMap { performance -> (Date, State.NextMine)? in
        guard let startsAt = performance.startsAt,
              let start = parse(startsAt), start > now else { return nil }
        return (
          start,
          State.NextMine(
            setId: performance.id,
            stageId: performance.stageId ?? "",
            stageName: stageName(
              for: performance,
              in: pack
            ),
            artist: performance.artist ?? "공연",
            startsAt: startsAt,
            isSaved: savedSetIDs.contains(performance.id)
          )
        )
      }
      .sorted { $0.0 < $1.0 }
    let nextMine = nextPerformances.first(where: { $0.1.isSaved == true })?.1
      ?? nextPerformances.first?.1
    return Self(
      nowStages: nowStages,
      nextMine: nextMine
    )
  }

  private static func parse(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }

  private static func stageName(
    for performance: FestivalPackDocument.Performance,
    in pack: FestivalPackDocument?
  ) -> String? {
    let namedStage = performance.stageId.flatMap { id in
      pack?.stages?.first { $0.id == id }?.name
    }
    return [performance.stageName, namedStage]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
  }
}
