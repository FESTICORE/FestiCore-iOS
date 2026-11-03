//
//  FestiCoreLogLevel.swift
//  FestiCoreLogger
//
//  Created by FestiCore on 10/22/26.
//

import OSLog

public enum FestiCoreLogLevel: Int, Comparable, CaseIterable, Sendable {
  case debug
  case info
  case notice
  case error
  case fault

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

  var osLogType: OSLogType {
    switch self {
    case .debug: .debug
    case .info: .info
    case .notice: .default
    case .error: .error
    case .fault: .fault
    }
  }

  var emoji: String {
    switch self {
    case .debug: "⚪️"
    case .info: "🔵"
    case .notice: "🟢"
    case .error: "🟡"
    case .fault: "🔴"
    }
  }
}
