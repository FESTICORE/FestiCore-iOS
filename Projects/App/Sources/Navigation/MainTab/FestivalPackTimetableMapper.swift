import FeatureAssembly
import FestiCoreUtility
import Foundation

enum FestivalPackTimetableMapper {
  static func days(from pack: FestivalPackDocument) -> [TimetableDay] {
    let calendar = AppDateFormat.calendar

    let performances = pack.performances.compactMap { performance -> (Date, Date, FestivalPackDocument.Performance)? in
      guard let startsAt = parseDate(performance.startsAt),
            let endsAt = parseDate(performance.endsAt),
            endsAt > startsAt else { return nil }
      return (startsAt, endsAt, performance)
    }

    let grouped = Dictionary(grouping: performances) { item in
      calendar.startOfDay(for: item.0)
    }
    return grouped.keys.sorted().map { dayStart in
      let entries = grouped[dayStart, default: []].sorted { $0.0 < $1.0 }
      let stages = entries.reduce(into: [TimetableStage]()) { result, entry in
        let stageID = entry.2.stageId ?? entry.2.stageName ?? "stage-unassigned"
        guard !result.contains(where: { $0.id == stageID }) else { return }
        result.append(.init(id: stageID, name: entry.2.stageName ?? "무대 미정"))
      }
      let sets = entries.map { start, end, performance in
        TimetableSet(
          id: performance.id,
          artist: performance.artist ?? "출연진 미정",
          stageID: performance.stageId ?? performance.stageName ?? "stage-unassigned",
          start: Int(start.timeIntervalSince(dayStart) / 60),
          end: Int(end.timeIntervalSince(dayStart) / 60)
        )
      }
      return TimetableDay(
        id: dayStart.formatted(.day),
        title: dayStart.formatted(.festivalDay),
        date: dayStart,
        stages: stages,
        sets: sets
      )
    }
  }

  private static func parseDate(_ value: String?) -> Date? {
    value?.isoDate
  }
}
