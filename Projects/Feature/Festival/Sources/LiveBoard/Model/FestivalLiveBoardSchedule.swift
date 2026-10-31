import Foundation

struct FestivalLiveBoardSchedule {
  struct Slot: Equatable {
    let id: String
    let artist: String
    let startsAt: Date
    let endsAt: Date?

    func progress(toward nextStart: Date, at date: Date) -> Double {
      guard nextStart > startsAt else { return 0 }
      return min(max(date.timeIntervalSince(startsAt) / nextStart.timeIntervalSince(startsAt), 0), 1)
    }
  }

  struct Stage: Equatable, Identifiable {
    let id: String
    let name: String
    let current: Slot?
    let previous: Slot?
    let next: Slot?
  }

  struct Entry: Equatable {
    let stageName: String
    let slot: Slot
  }

  /// 팩의 모든 공연을 무대 이름과 함께 시작 시각 순으로 돌려준다.
  static func entries(pack: FestivalPackDocument) -> [Entry] {
    let namesByID = Dictionary((pack.stages ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    return pack.performances.compactMap { performance -> Entry? in
      guard
        let start = performance.startsAt.flatMap(parse),
        let artist = nonempty(performance.artist),
        let stageID = nonempty(performance.stageId) ?? nonempty(performance.stageName)
      else { return nil }
      let end = performance.endsAt.flatMap(parse)
      if let end, end <= start { return nil }
      let name = nonempty(performance.stageName) ?? namesByID[stageID] ?? stageID
      return Entry(stageName: name, slot: Slot(id: performance.id, artist: artist, startsAt: start, endsAt: end))
    }
    .sorted { $0.slot.startsAt == $1.slot.startsAt ? $0.slot.id < $1.slot.id : $0.slot.startsAt < $1.slot.startsAt }
  }

  static func resolve(pack: FestivalPackDocument, now: Date) -> [Stage] {
    let namesByID = Dictionary((pack.stages ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    var stageOrder: [String] = []
    var stageNames: [String: String] = [:]
    var slots: [String: [Slot]] = [:]

    for performance in pack.performances {
      guard
        let start = performance.startsAt.flatMap(parse),
        let artist = nonempty(performance.artist),
        let stageID = nonempty(performance.stageId) ?? nonempty(performance.stageName)
      else { continue }

      let end = performance.endsAt.flatMap(parse)
      if let end, end <= start { continue }
      if stageNames[stageID] == nil {
        stageOrder.append(stageID)
        stageNames[stageID] = nonempty(performance.stageName) ?? namesByID[stageID] ?? stageID
      }
      slots[stageID, default: []].append(Slot(
        id: performance.id, artist: artist, startsAt: start, endsAt: end
      ))
    }

    return stageOrder.compactMap { stageID in
      let ordered = (slots[stageID] ?? []).sorted {
        $0.startsAt == $1.startsAt ? $0.id < $1.id : $0.startsAt < $1.startsAt
      }
      let current = ordered.last { slot in
        slot.startsAt <= now && (slot.endsAt.map { now < $0 } ?? false)
      }
      let previous = ordered.last { $0.startsAt <= now }
      let next = ordered.first { $0.startsAt > now }
      guard current != nil || next != nil, let name = stageNames[stageID] else { return nil }
      return Stage(id: stageID, name: name, current: current, previous: previous, next: next)
    }
  }

  private static func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }

  static func parse(_ value: String) -> Date? {
    guard value.range(
      of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#,
      options: .regularExpression
    ) != nil else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}
