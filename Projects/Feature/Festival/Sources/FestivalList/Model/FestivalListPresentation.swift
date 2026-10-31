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

}
