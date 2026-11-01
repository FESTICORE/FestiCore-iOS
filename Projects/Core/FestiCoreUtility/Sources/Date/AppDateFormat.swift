//
//  AppDateFormat.swift
//  FestiCoreUtility
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

public enum AppDateFormat: String, CaseIterable, Sendable {
  case day = "yyyy-MM-dd"
  case time = "HH:mm"
  case festivalDay = "M/d(E)"
  case liveBoardDay = "MM.dd (E)"
  case monthDayTime = "MM/dd HH:mm"

  public static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt

  public static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }

  /// 요일을 쓰는 화면 표기는 한국어, 나머지는 고정 형식으로 만든다.
  fileprivate var locale: Locale {
    switch self {
    case .festivalDay, .liveBoardDay: Locale(identifier: "ko_KR")
    case .day, .time, .monthDayTime: Locale(identifier: "en_US_POSIX")
    }
  }
}

/// 포매터는 한 번만 만들고 이후 설정을 바꾸지 않는다.
private enum AppDateFormatter {
  nonisolated(unsafe) static let formatters: [AppDateFormat: DateFormatter] = Dictionary(
    uniqueKeysWithValues: AppDateFormat.allCases.map { format in
      let formatter = DateFormatter()
      formatter.locale = format.locale
      formatter.timeZone = AppDateFormat.timeZone
      formatter.calendar = AppDateFormat.calendar
      formatter.dateFormat = format.rawValue
      formatter.isLenient = false
      return (format, formatter)
    }
  )

  nonisolated(unsafe) static let isoFractionalParser: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  nonisolated(unsafe) static let isoParser: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// 서버는 ms 단위로 비교하므로 소수점 3자리와 서울 오프셋으로 보낸다.
  nonisolated(unsafe) static let isoSeoulWriter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = AppDateFormat.timeZone
    return formatter
  }()

  static subscript(format: AppDateFormat) -> DateFormatter {
    formatters[format]!
  }

  /// 서버 날짜는 형식이 정확히 일치할 때만 받아들인다.
  static func date(from value: String, as format: AppDateFormat) -> Date? {
    let formatter = self[format]
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
      return nil
    }
    return date
  }
}

public extension String {
  func date(as format: AppDateFormat) -> Date? {
    AppDateFormatter.date(from: self, as: format)
  }

  /// ISO 8601 시각. 소수초가 있든 없든 받아들인다.
  var isoDate: Date? {
    AppDateFormatter.isoFractionalParser.date(from: self) ?? AppDateFormatter.isoParser.date(from: self)
  }
}

public extension Date {
  func formatted(_ format: AppDateFormat) -> String {
    AppDateFormatter[format].string(from: self)
  }

  /// `yyyy-MM-ddTHH:mm:ss.SSS+09:00`
  var isoString: String {
    AppDateFormatter.isoSeoulWriter.string(from: self)
  }
}
