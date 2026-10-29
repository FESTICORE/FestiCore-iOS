import Foundation

struct FestivalLiveActivitySchedule: Equatable, Sendable {
  enum Phase: String, Equatable, Sendable {
    case upcoming
    case ongoing
    case finished
  }

  let startDate: Date
  let endDate: Date
  let phase: Phase
  let canStart: Bool
  let nextBoundary: Date?

  static func resolve(
    festival: FestivalOverview,
    pack: FestivalPackDocument?,
    now: Date
  ) -> Self? {
    let packDates = (pack?.days ?? []).compactMap(\.date)
    let packStarts = packDates.compactMap { parse($0, endOfDay: false) }
    let packEnds = packDates.compactMap { parse($0, endOfDay: true) }

    let catalogStart = festival.firstDate?.trimmingCharacters(in: .whitespacesAndNewlines)
    let catalogEnd = festival.lastDate?.trimmingCharacters(in: .whitespacesAndNewlines)
    let startDate = catalogStart.flatMap { $0.isEmpty ? packStarts.min() : parse($0, endOfDay: false) }
      ?? (catalogStart == nil ? packStarts.min() : nil)
    let endDate = catalogEnd.flatMap { $0.isEmpty ? packEnds.max() : parse($0, endOfDay: true) }
      ?? (catalogEnd == nil ? packEnds.max() : nil)

    guard
      let startDate,
      let endDate,
      startDate < endDate
    else {
      return nil
    }

    let eligibilityStart = startDate.addingTimeInterval(-2 * 60 * 60)
    let phase: Phase
    let nextBoundary: Date?
    if now < startDate {
      phase = .upcoming
      nextBoundary = now < eligibilityStart ? eligibilityStart : startDate
    } else if now < endDate {
      phase = .ongoing
      nextBoundary = endDate
    } else {
      phase = .finished
      nextBoundary = nil
    }

    return Self(
      startDate: startDate,
      endDate: endDate,
      phase: phase,
      canStart: eligibilityStart <= now && now < endDate,
      nextBoundary: nextBoundary
    )
  }

  static func packDateBounds(_ days: [FestivalPackDocument.Day]) -> (first: String, last: String)? {
    let valid = days.compactMap { day -> (raw: String, start: Date, end: Date)? in
      guard
        let raw = day.date,
        let start = parse(raw, endOfDay: false),
        let end = parse(raw, endOfDay: true)
      else {
        return nil
      }
      return (raw, start, end)
    }
    guard
      let first = valid.min(by: { $0.start < $1.start }),
      let last = valid.max(by: { $0.end < $1.end })
    else {
      return nil
    }
    return (first.raw, last.raw)
  }

  private static let seoul = TimeZone(identifier: "Asia/Seoul")!

  private static func parse(_ value: String, endOfDay: Bool) -> Date? {
    if value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
      return parseDay(value, endOfDay: endOfDay)
    }
    return parseTimestamp(value)
  }

  private static func parseDay(_ value: String, endOfDay: Bool) -> Date? {
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = seoul
    let components = DateComponents(
      timeZone: seoul, year: parts[0], month: parts[1], day: parts[2]
    )
    guard
      let start = calendar.date(from: components),
      calendar.component(.year, from: start) == parts[0],
      calendar.component(.month, from: start) == parts[1],
      calendar.component(.day, from: start) == parts[2]
    else {
      return nil
    }
    return endOfDay ? calendar.date(byAdding: .day, value: 1, to: start) : start
  }

  private static func parseTimestamp(_ value: String) -> Date? {
    let pattern = #"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$"#
    guard
      let expression = try? NSRegularExpression(pattern: pattern),
      let match = expression.firstMatch(
        in: value, range: NSRange(value.startIndex..., in: value)
      ),
      match.range.length == (value as NSString).length
    else {
      return nil
    }

    func group(_ index: Int) -> Int? {
      guard let range = Range(match.range(at: index), in: value) else { return nil }
      return Int(value[range])
    }

    guard
      let year = group(1), let month = group(2), let day = group(3),
      let hour = group(4), let minute = group(5), let second = group(6),
      hour < 24, minute < 60, second < 60,
      let offsetRange = Range(match.range(at: 8), in: value)
    else {
      return nil
    }

    let offset = value[offsetRange]
    let secondsFromGMT: Int
    if offset == "Z" {
      secondsFromGMT = 0
    } else {
      let digits = offset.dropFirst().split(separator: ":").compactMap { Int($0) }
      guard digits.count == 2, digits[0] <= 18, digits[1] < 60 else { return nil }
      secondsFromGMT = (offset.first == "-" ? -1 : 1) * (digits[0] * 3600 + digits[1] * 60)
    }
    guard let timezone = TimeZone(secondsFromGMT: secondsFromGMT) else { return nil }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timezone
    var components = DateComponents(
      timeZone: timezone, year: year, month: month, day: day,
      hour: hour, minute: minute, second: second
    )
    if let fraction = group(7), let range = Range(match.range(at: 7), in: value) {
      components.nanosecond = fraction * Int(pow(10.0, Double(9 - value[range].count)))
    }
    guard
      let date = calendar.date(from: components),
      calendar.component(.year, from: date) == year,
      calendar.component(.month, from: date) == month,
      calendar.component(.day, from: date) == day,
      calendar.component(.hour, from: date) == hour,
      calendar.component(.minute, from: date) == minute,
      calendar.component(.second, from: date) == second
    else {
      return nil
    }
    return date
  }
}
