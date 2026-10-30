//
//  FestivalDateFormat.swift
//  FestiCoreUtility
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

public enum FestivalDateFormat: String, CaseIterable, Sendable {
  case day = "yyyy-MM-dd"
  case time = "HH:mm"
  case festivalDay = "M/d(E)"

  public static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt

  public static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }
}

private enum FestivalDateFormatter {
  static func make(_ format: FestivalDateFormat) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: format == .festivalDay ? "ko_KR" : "en_US_POSIX")
    formatter.timeZone = FestivalDateFormat.timeZone
    formatter.calendar = FestivalDateFormat.calendar
    formatter.dateFormat = format.rawValue
    formatter.isLenient = false
    return formatter
  }

  /// 서버 날짜는 형식이 정확히 일치할 때만 받아들인다.
  static func date(from value: String, as format: FestivalDateFormat) -> Date? {
    let formatter = make(format)
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
      return nil
    }
    return date
  }
}

public extension String {
  func date(as format: FestivalDateFormat) -> Date? {
    FestivalDateFormatter.date(from: self, as: format)
  }
}

public extension Date {
  func formatted(_ format: FestivalDateFormat) -> String {
    FestivalDateFormatter.make(format).string(from: self)
  }
}
