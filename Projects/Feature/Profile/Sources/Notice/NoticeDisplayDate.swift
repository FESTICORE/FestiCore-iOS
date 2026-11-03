//
//  NoticeDisplayDate.swift
//  Profile
//

import FestiCoreUtility
import Foundation

enum NoticeDisplayDate {
  static func format(_ publishedAt: String) -> String {
    guard let date = publishedAt.isoDate else { return "날짜 정보 없음" }
    return date.formatted(.day).replacingOccurrences(of: "-", with: ".")
  }
}
