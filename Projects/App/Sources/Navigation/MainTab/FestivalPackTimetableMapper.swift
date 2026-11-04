import FeatureAssembly
import FestivalDomainInterface
import FestiCoreUtility
import Foundation
import TimetableDomainInterface

enum FestivalPackTimetableMapper {
  /// `imageURL`은 팩의 상대 사진 경로를 서버 주소로 바꾼다.
  static func days(
    from pack: FestivalPackDocument,
    previousDays: [TimetableDay] = [],
    imageURL: (String?) -> URL? = { _ in nil }
  ) -> [TimetableDay] {
    let calendar = AppDateFormat.calendar

    let performances = pack.performances.compactMap { performance -> (Date, Date, FestivalPackDocument.Performance)? in
      guard let startsAt = parseDate(performance.startsAt),
            let endsAt = parseDate(performance.endsAt),
            endsAt > startsAt else { return nil }
      return (startsAt, endsAt, performance)
    }

    if pack.performances.isEmpty {
      return (pack.days ?? []).compactMap { day in
        guard let value = day.date ?? day.startsAt,
              let date = value.date(as: .day) ?? parseDate(value) else { return nil }
        let start = calendar.startOfDay(for: date)
        return TimetableDay(
          id: start.formatted(.day),
          title: start.formatted(.festivalDay),
          date: start,
          stages: [],
          sets: []
        )
      }
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
        let previous = previousDays.first(where: { $0.date == dayStart })?.sets.first { $0.id == performance.id }
        let minute = Int(start.timeIntervalSince(dayStart) / 60)
        return TimetableSet(
          id: performance.id,
          artist: performance.artist ?? "출연진 미정",
          stageID: performance.stageId ?? performance.stageName ?? "stage-unassigned",
          start: Int(start.timeIntervalSince(dayStart) / 60),
          end: Int(end.timeIntervalSince(dayStart) / 60),
          previousStart: previous.map { $0.start == minute ? $0.previousStart : $0.start } ?? nil,
          imageURL: imageURL(performance.imageUrl)
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

  static func lineup(from pack: FestivalPackDocument) -> [TimetableLineupDay] {
    let names = (pack.artists ?? []).map(\.name).filter { !$0.isEmpty }
    guard !names.isEmpty else { return [] }
    return [TimetableLineupDay(
      id: pack.id,
      title: "공개된 라인업",
      artists: names
    )]
  }

  static func source(_ source: FestivalPackDocument.Source?) -> String {
    guard let name = source?.name, !name.isEmpty else { return "" }
    guard let verifiedAt = source?.verifiedAt?.isoDate else { return "출처: \(name)" }
    return "출처: \(name) · 확인 \(verifiedAt.formatted(.monthDayTime))"
  }

  private static func parseDate(_ value: String?) -> Date? {
    return value?.isoDate
  }
}
