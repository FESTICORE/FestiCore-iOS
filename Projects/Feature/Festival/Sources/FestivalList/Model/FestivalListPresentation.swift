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
    let calendar = FestivalDateFormat.calendar
    guard let firstDate = festival.firstDate, let first = firstDate.date(as: .day) else { return .undated }
    let today = calendar.startOfDay(for: now)
    let last = festival.lastDate?.date(as: .day) ?? first
    if today > last { return .ended }
    let days = calendar.dateComponents([.day], from: today, to: first).day ?? 0
    return days > 0 ? .daysUntil(days) : .live
  }

  /// 줄바꿈으로 저장한 최근 검색어를 최신순으로 돌려준다.
  static func recentSearches(from storage: String) -> [String] {
    storage
      .split(separator: "\n")
      .map(String.init)
      .filter { !$0.isEmpty }
  }

  /// 검색어를 맨 앞에 넣고 중복을 없앤 뒤 최대 개수만 남긴 저장 문자열을 돌려준다.
  static func recentSearchStorage(
    adding keyword: String,
    to storage: String,
    limit: Int = 10
  ) -> String {
    let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keyword.isEmpty else { return storage }
    let existing = recentSearches(from: storage).filter { $0 != keyword }
    return ([keyword] + existing)
      .prefix(limit)
      .joined(separator: "\n")
  }
}
