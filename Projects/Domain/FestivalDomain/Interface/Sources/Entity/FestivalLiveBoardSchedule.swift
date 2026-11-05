import Foundation
import FestiCoreUtility

/// 팩에서 검증한 공연 시각과 무대별 현재·이전·다음 공연을 전달한다.
public enum FestivalLiveBoardSchedule {
  public struct Slot: Equatable, Sendable {
    public let id: String
    public let artist: String
    public let startsAt: Date
    public let endsAt: Date?

    public init(
      id: String,
      artist: String,
      startsAt: Date,
      endsAt: Date?
    ) {
      self.id = id
      self.artist = artist
      self.startsAt = startsAt
      self.endsAt = endsAt
    }
  }

  public struct Stage: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let current: Slot?
    public let previous: Slot?
    public let next: Slot?

    public init(
      id: String,
      name: String,
      current: Slot?,
      previous: Slot?,
      next: Slot?
    ) {
      self.id = id
      self.name = name
      self.current = current
      self.previous = previous
      self.next = next
    }
  }

  public struct Entry: Equatable, Sendable {
    public let stageName: String
    public let slot: Slot

    public init(
      stageName: String,
      slot: Slot
    ) {
      self.stageName = stageName
      self.slot = slot
    }
  }

  /// 유효한 팩 공연을 무대 이름과 함께 시작 시각·공연 ID 순으로 반환한다.
  public static func entries(from pack: FestivalPackDocument) -> [Entry] {
    let stageNames = Dictionary(
      (pack.stages ?? []).map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first }
    )
    return pack.performances.compactMap { performance -> Entry? in
      guard
        let start = performance.startsAt.flatMap(parse),
        let artist = nonempty(performance.artist),
        let stageID = nonempty(performance.stageId) ?? nonempty(performance.stageName)
      else { return nil }
      let end = performance.endsAt.flatMap(parse)
      guard end.map({ $0 > start }) ?? true else { return nil }
      let stageName = nonempty(performance.stageName) ?? stageNames[stageID] ?? stageID
      return Entry(
        stageName: stageName,
        slot: Slot(
          id: performance.id,
          artist: artist,
          startsAt: start,
          endsAt: end
        )
      )
    }
    .sorted {
      $0.slot.startsAt == $1.slot.startsAt
        ? $0.slot.id < $1.slot.id
        : $0.slot.startsAt < $1.slot.startsAt
    }
  }

  /// 시작은 포함하고 종료는 제외해 무대별 현재·이전·다음 공연을 계산한다.
  public static func stages(
    from pack: FestivalPackDocument,
    at now: Date
  ) -> [Stage] {
    let stageNames = Dictionary(
      (pack.stages ?? []).map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first }
    )
    var stageOrder: [String] = []
    var names: [String: String] = [:]
    var slots: [String: [Slot]] = [:]

    for performance in pack.performances {
      guard
        let start = performance.startsAt.flatMap(parse),
        let artist = nonempty(performance.artist),
        let stageID = nonempty(performance.stageId) ?? nonempty(performance.stageName)
      else { continue }
      let end = performance.endsAt.flatMap(parse)
      guard end.map({ $0 > start }) ?? true else { continue }
      if names[stageID] == nil {
        stageOrder.append(stageID)
        names[stageID] = nonempty(performance.stageName) ?? stageNames[stageID] ?? stageID
      }
      slots[stageID, default: []].append(Slot(
        id: performance.id,
        artist: artist,
        startsAt: start,
        endsAt: end
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
      guard current != nil || next != nil, let name = names[stageID] else { return nil }
      return Stage(
        id: stageID,
        name: name,
        current: current,
        previous: previous,
        next: next
      )
    }
  }

  private static func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func parse(_ value: String) -> Date? {
    guard value.range(
      of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#,
      options: .regularExpression
    ) != nil else { return nil }
    return value.isoDate
  }

}
