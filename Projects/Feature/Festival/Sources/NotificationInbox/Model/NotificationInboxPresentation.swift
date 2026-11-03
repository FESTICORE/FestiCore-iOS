import FestiCoreDesignKit
import FestiCoreUtility
import Foundation
import UserNotificationDomainInterface

enum NotificationInboxPresentation {
  struct Section: Equatable, Identifiable {
    let id: String
    let title: String
    let items: [UserNotificationItem]
  }

  static func sections(_ items: [UserNotificationItem], now: Date) -> [Section] {
    var sections: [Section] = []
    let calendar = AppDateFormat.calendar
    for item in items {
      let day = calendar.startOfDay(for: item.createdAt)
      let id = day.formatted(.day)
      let title: String
      if calendar.isDate(day, inSameDayAs: now) {
        title = "오늘"
      } else if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
        title = "어제"
      } else { title = id }
      if let index = sections.firstIndex(where: { $0.id == id }) {
        sections[index] = Section(id: id, title: title, items: sections[index].items + [item])
      } else {
        sections.append(Section(id: id, title: title, items: [item]))
      }
    }
    return sections
  }

  static func time(for item: UserNotificationItem, now: Date) -> String {
    let calendar = AppDateFormat.calendar
    if calendar.isDate(item.createdAt, inSameDayAs: now) {
      return FestivalLiveBoardPresentation.relativeTime(item.createdAt, now: now) ?? "방금"
    }
    if calendar.isDate(item.createdAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
      return "어제 \(item.createdAt.formatted(.time))"
    }
    return item.createdAt.formatted(.monthDayTime)
  }

  static func icon(for type: String) -> ImageAsset {
    if type.hasPrefix("crew.") { return .users24 }
    if type.hasPrefix("flag.") { return .flag16 }
    if type.hasPrefix("festival.") { return .music24 }
    if type.hasPrefix("pack.") { return .bookmark16 }
    return .bell16
  }
}
