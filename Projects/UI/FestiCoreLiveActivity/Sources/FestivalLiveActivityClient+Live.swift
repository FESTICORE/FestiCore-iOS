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
    update: { id, phase, startDate, endDate, pack, savedSetIDs in
      let presentation = FestivalActivityPresentation.from(
        pack: pack,
        savedSetIDs: savedSetIDs ?? [],
        now: Date()
      )
      await FestiCoreFestivalLiveActivity.update(
        id: id,
        phase: .init(rawValue: phase.rawValue) ?? .upcoming,
        startDate: startDate,
        endDate: endDate,
        nowStages: pack == nil ? nil : presentation.nowStages,
        nextMine: presentation.nextMine,
        // 내 일정을 모르거나, 저장 공연은 있는데 팩이 없어 계산할 수 없으면 표시 중인 값을 유지한다.
        // 내 일정이 비었다고 확인되면 팩이 없어도 지운다.
        isNextMineKnown: savedSetIDs.map { $0.isEmpty || pack != nil } ?? false
      )
    },
    finish: { id, startDate in
      await FestiCoreFestivalLiveActivity.endFinished(id: id, startDate: startDate)
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
    let nextMine = performances
      .filter { savedSetIDs.contains($0.id) }
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
            startsAt: startsAt
          )
        )
      }
      .min { $0.0 < $1.0 }?.1
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
