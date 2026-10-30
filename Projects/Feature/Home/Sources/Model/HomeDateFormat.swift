import Foundation

/// Attendance의 AppDateFormat과 같은 POSIX 로케일·서울 시간대·Gregorian 규칙을 사용한다.
enum HomeDateFormat {
  private static let locale = Locale(identifier: "en_US_POSIX")
  static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt

  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }

  static func day(from value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = makeFormatter("yyyy-MM-dd")
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
      return nil
    }
    return date
  }

  static func time(from date: Date) -> String {
    makeFormatter("HH:mm").string(from: date)
  }

  static func festivalDay(from value: String?) -> String? {
    guard let date = day(from: value) else { return nil }
    let formatter = makeFormatter("M/d(E)")
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: date)
  }

  private static func makeFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.calendar = calendar
    formatter.dateFormat = format
    formatter.isLenient = false
    return formatter
  }
}
