import FeatureAssembly
import Foundation

enum FestivalPackTimetableMapper {
  static func days(from pack: FestivalPackDocument) -> [TimetableDay] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = calendar
    dateFormatter.timeZone = calendar.timeZone
    dateFormatter.locale = Locale(identifier: "ko_KR")
    dateFormatter.dateFormat = "M/d(E)"

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
        id: dayID(dayStart, calendar: calendar),
        title: dateFormatter.string(from: dayStart),
        date: dayStart,
        stages: stages,
        sets: sets
      )
    }
  }

  private static func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }

  private static func dayID(_ date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
  }
}
