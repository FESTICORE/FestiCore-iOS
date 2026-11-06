import FestiCoreUtility
import FestivalDomainInterface
import Foundation

/// 화면에는 Domain이 판정한 일정과 표시용 날짜 변환만 전달한다.
struct FestivalLiveBoardSchedule {
  typealias Slot = FestivalDomainInterface.FestivalLiveBoardSchedule.Slot
  typealias Stage = FestivalDomainInterface.FestivalLiveBoardSchedule.Stage
  typealias Entry = FestivalDomainInterface.FestivalLiveBoardSchedule.Entry

  static func entries(pack: FestivalPackDocument) -> [Entry] {
    return FestivalDomainInterface.FestivalLiveBoardSchedule.entries(from: pack)
  }

  static func resolve(
    pack: FestivalPackDocument,
    now: Date
  ) -> [Stage] {
    return FestivalDomainInterface.FestivalLiveBoardSchedule.stages(
      from: pack,
      at: now
    )
  }

  static func parse(_ value: String) -> Date? {
    guard
      value.range(
        of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#,
        options: .regularExpression
      ) != nil
    else { return nil }
    return value.isoDate
  }
}

extension FestivalDomainInterface.FestivalLiveBoardSchedule.Slot {
  func progress(
    toward nextStart: Date,
    at date: Date
  ) -> Double {
    guard nextStart > startsAt else { return 0 }
    return min(
      max(
        date.timeIntervalSince(startsAt) / nextStart.timeIntervalSince(startsAt),
        0
      ),
      1
    )
  }
}
