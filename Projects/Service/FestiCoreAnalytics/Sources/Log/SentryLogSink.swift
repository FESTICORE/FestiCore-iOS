//
//  SentryLogSink.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreLogger
@preconcurrency import Sentry

/// FestiCoreLogger 로그를 Sentry Logs로 보낸다. 분석 이벤트 추적과는 별개다.
///
/// 네트워크 로그는 URL·응답 본문이 들어갈 수 있어 보내지 않는다.
/// 네트워크 실패는 Sentry의 실패 요청 캡처와 네트워크 breadcrumb가 따로 남긴다.
struct SentryLogSink: FestiCoreLogSink {
  enum Level: Equatable {
    case debug
    case info
    case warn
    case error
    case fatal
  }

  private let write: @Sendable (Level, String, [String: Any]) -> Void

  init(write: @escaping @Sendable (Level, String, [String: Any]) -> Void = { SentryLogSink.writeToSentry($0, $1, $2) }) {
    self.write = write
  }

  static func level(for level: FestiCoreLogLevel) -> Level {
    switch level {
    case .debug: .debug
    case .info: .info
    case .notice: .warn
    case .error: .error
    case .fault: .fatal
    }
  }

  static func attributes(for entry: FestiCoreLogEntry) -> [String: Any] {
    [
      "category": entry.category.rawValue,
      "code.file": entry.file,
      "code.function": entry.function,
      "code.line": entry.line
    ]
  }

  func send(_ entry: FestiCoreLogEntry) {
    guard entry.category != .network else { return }
    write(Self.level(for: entry.level), entry.message, Self.attributes(for: entry))
  }

  static func writeToSentry(_ level: Level, _ message: String, _ attributes: [String: Any]) {
    let logger = SentrySDK.logger
    switch level {
    case .debug: logger.debug(message, attributes: attributes)
    case .info: logger.info(message, attributes: attributes)
    case .warn: logger.warn(message, attributes: attributes)
    case .error: logger.error(message, attributes: attributes)
    case .fatal: logger.fatal(message, attributes: attributes)
    }
  }
}
