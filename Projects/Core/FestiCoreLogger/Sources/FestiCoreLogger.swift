//
//  FestiCoreLogger.swift
//  FestiCoreLogger
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import os
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

  /// 외부 출력 대상에는 info 이상만 보낸다. 릴리스는 `minimumLevel`(notice) 이상만 남는다.
  static let sinkMinimumLevel: FestiCoreLogLevel = .info
  private static let sinks = OSAllocatedUnfairLock<[any FestiCoreLogSink]>(initialState: [])

  /// 앱 시작 시 SDK를 아는 모듈이 출력 대상을 등록한다.
  public static func addSink(_ sink: any FestiCoreLogSink) {
    sinks.withLock { $0.append(sink) }
  }

  static func removeAllSinks() {
    sinks.withLock { $0.removeAll() }
  }

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
    guard level >= sinkMinimumLevel else { return }
    let entry = FestiCoreLogEntry(level: level, category: category, message: message, file: file, function: function, line: line)
    for sink in sinks.withLock({ $0 }) {
      sink.send(entry)
    }
  }
}
