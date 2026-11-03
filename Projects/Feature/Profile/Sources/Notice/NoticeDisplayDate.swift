//
//  NoticeDisplayDate.swift
//  Profile
//

import Foundation
import FestiCoreUtility

enum NoticeDisplayDate {
  static func format(_ publishedAt: Date) -> String {
    publishedAt.formatted(.day).replacingOccurrences(of: "-", with: ".")
  }
}
