//
//  FestiCoreLogger.swift
//  FestiCoreLogger
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import OSLog

/// Privacy-preserving OSLog entry point shared by core modules.
public enum FestiCoreLogger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "io.festiCore.co"
  static let minimumLevel: FestiCoreLogLevel = {
    #if DEBUG
    .debug
    #else
    .notice
    #endif
  }()

  public static func debug(_ message: String, category: FestiCoreLogCategory, fileID: String = #fileID, function: String = #function, line: Int = #line) {
    emit(.debug, message, category, fileID, function, line)
  }

  public static func info(_ message: String, category: FestiCoreLogCategory, fileID: String = #fileID, function: String = #function, line: Int = #line) {
    emit(.info, message, category, fileID, function, line)
  }

  public static func notice(_ message: String, category: FestiCoreLogCategory, fileID: String = #fileID, function: String = #function, line: Int = #line) {
    emit(.notice, message, category, fileID, function, line)
  }

  public static func error(_ message: String, category: FestiCoreLogCategory, fileID: String = #fileID, function: String = #function, line: Int = #line) {
    emit(.error, message, category, fileID, function, line)
  }

  public static func fault(_ message: String, category: FestiCoreLogCategory, fileID: String = #fileID, function: String = #function, line: Int = #line) {
    emit(.fault, message, category, fileID, function, line)
  }

  private static func emit(_ level: FestiCoreLogLevel, _ message: String, _ category: FestiCoreLogCategory, _ fileID: String, _ function: String, _ line: Int) {
    guard level >= minimumLevel else { return }
    let file = fileID.split(separator: "/").last.map(String.init) ?? fileID
    Logger(subsystem: subsystem, category: category.rawValue).log(
      level: level.osLogType,
      "\(level.emoji, privacy: .public) [\(category.rawValue, privacy: .public)] \(message, privacy: .private) ↳ \(file, privacy: .public):\(line, privacy: .public) \(function, privacy: .public)"
    )
  }
}
