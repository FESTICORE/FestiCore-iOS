import FestiCoreUtility
import Foundation

enum FestivalListPresentation {
  enum Timing: Equatable {
    case daysUntil(Int)
    case live
    case ended
    case undated
  }

  static func visible(
    _ festivals: [FestivalOverview],
    query: String,
    bookedIDs: Set<String>,
    onlyBooked: Bool
  ) -> [FestivalOverview] {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return festivals.filter { festival in
      (!onlyBooked || bookedIDs.contains(festival.id))
        && (search.isEmpty
          || festival.name.localizedStandardContains(search)
          || festival.venue?.localizedStandardContains(search) == true)
    }
  }

  static func timing(for festival: FestivalOverview, now: Date) -> Timing {
    let calendar = AppDateFormat.calendar
    let today = calendar.startOfDay(for: now)
    let validLast = festival.lastDate?.date(as: .day)
    guard let firstDate = festival.firstDate, let first = firstDate.date(as: .day) else {
      // 시작일이 없거나 잘못돼도 지난 종료일이 있으면 종료로 본다.
      if let validLast, today > validLast { return .ended }
      return .undated
    }
    let last = validLast ?? first
    if today > last { return .ended }
    let days = calendar.dateComponents([.day], from: today, to: first).day ?? 0
    return days > 0 ? .daysUntil(days) : .live
  }
}

// MARK: - 카드 (Figma S00 Festival Card)

extension FestivalListPresentation {
  enum CardStatus: Equatable {
    case dDay(String)
    case closing(String)
    case upcoming
    case ended
  }

  enum PackCopy: Equatable {
    case unavailable(String)
    case ready(String)
    case received(String)
  }

  /// 티켓이 아직 열리지 않아 팩을 받을 수 없는 축제
  static func isOpeningSoon(_ festival: FestivalOverview) -> Bool {
    festival.catalogStatus == "discovered" || festival.packVersion == 0
  }

  /// 종료 > 오픈 예정 > 진행 중 > D-3~D-1(빨강) > D-4 이상 > 날짜 없음
  static func cardStatus(for festival: FestivalOverview, now: Date) -> CardStatus {
    let timing = timing(for: festival, now: now)
    if timing == .ended { return .ended }
    if isOpeningSoon(festival) { return .upcoming }
    switch timing {
    case .live: return .dDay("진행 중")
    case let .daysUntil(days): return days <= 3 ? .closing("D-\(days)") : .dDay("D-\(days)")
    case .undated: return .dDay("일정 확인")
    case .ended: return .ended
    }
  }

  static func packCopy(
    for festival: FestivalOverview,
    isBooked: Bool,
    onlyBooked: Bool,
    now: Date
  ) -> PackCopy {
    if timing(for: festival, now: now) == .ended {
      return .unavailable("종료된 페스티벌이라 팩을 받을 수 없어요")
    }
    if isOpeningSoon(festival) {
      return .unavailable(onlyBooked ? "티켓이 열리면 팩을 받을 수 있어요" : "티켓 오픈 후 등록하고 팩을 받을 수 있어요")
    }
    guard isBooked else { return .unavailable("예매한 페스티벌로 등록하면 팩을 받을 수 있어요") }
    guard let cachedVersion = festival.cachedPackVersion else { return .ready("팩 받기") }
    // 카탈로그 캐시가 팩보다 오래됐을 수 있으므로 같거나 높으면 최신으로 본다.
    return cachedVersion >= festival.packVersion ? .received("팩 받음 · 최신 버전") : .ready("팩 업데이트")
  }

  /// 진행 중 → 가까운 D-day → 오픈 예정·날짜 없음 → 종료(최근 종료 먼저). 같은 순위는 이름순.
  static func sorted(_ festivals: [FestivalOverview], now: Date) -> [FestivalOverview] {
    festivals
      .map { (festival: $0, key: sortKey(for: $0, now: now)) }
      .sorted { lhs, rhs in
        if lhs.key.rank != rhs.key.rank { return lhs.key.rank < rhs.key.rank }
        if lhs.key.order != rhs.key.order { return lhs.key.order < rhs.key.order }
        return lhs.festival.name.localizedStandardCompare(rhs.festival.name) == .orderedAscending
      }
      .map(\.festival)
  }

  private static func sortKey(for festival: FestivalOverview, now: Date) -> (rank: Int, order: Int) {
    let timing = timing(for: festival, now: now)
    if timing == .ended {
      // timing과 같이 파싱에 성공한 종료일, 없으면 시작일을 쓴다.
      let lastDay = festival.lastDate?.date(as: .day) ?? festival.firstDate?.date(as: .day)
      let last = lastDay.map { Int($0.timeIntervalSince1970) } ?? 0
      return (3, -last)
    }
    if isOpeningSoon(festival) {
      return (2, festival.firstDate?.date(as: .day).map { Int($0.timeIntervalSince1970) } ?? Int.max)
    }
    switch timing {
    case .live: return (0, 0)
    case let .daysUntil(days): return (1, days)
    case .undated, .ended: return (2, Int.max)
    }
  }
}
