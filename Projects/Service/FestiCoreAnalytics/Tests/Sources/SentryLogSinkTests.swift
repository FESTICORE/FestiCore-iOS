//
//  SentryLogSinkTests.swift
//  FestiCoreAnalyticsTests
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreLogger
import os
import Testing
@testable import FestiCoreAnalytics

struct SentryLogSinkTests {
  @Test func mapsLoggerLevelsToSentryLevels() {
    #expect(SentryLogSink.level(for: .debug) == .debug)
    #expect(SentryLogSink.level(for: .info) == .info)
    #expect(SentryLogSink.level(for: .notice) == .warn)
    #expect(SentryLogSink.level(for: .error) == .error)
    #expect(SentryLogSink.level(for: .fault) == .fatal)
  }

  @Test func forwardsMessageWithCategoryAttribute() {
    let written = OSAllocatedUnfairLock<[(SentryLogSink.Level, String, String?)]>(uncheckedState: [])
    let sink = SentryLogSink { level, message, attributes in
      written.withLockUnchecked { $0.append((level, message, attributes["category"] as? String)) }
    }

    sink.send(entry(.error, .auth, "로그인 실패"))

    let records = written.withLockUnchecked { $0 }
    #expect(records.count == 1)
    #expect(records.first?.0 == .error)
    #expect(records.first?.1 == "로그인 실패")
    #expect(records.first?.2 == "auth")
  }

  @Test func attributesCarryCodeLocation() {
    let attributes = SentryLogSink.attributes(for: entry(.info, .festival, "팩 갱신"))
    #expect(attributes["category"] as? String == "festival")
    #expect(attributes["code.file"] as? String == "File.swift")
    #expect(attributes["code.function"] as? String == "run()")
    #expect(attributes["code.line"] as? Int == 7)
  }

  @Test func skipsNetworkLogs() {
    let count = OSAllocatedUnfairLock(initialState: 0)
    let sink = SentryLogSink { _, _, _ in count.withLock { $0 += 1 } }

    sink.send(entry(.error, .network, "GET https://example.invalid/me → 500"))

    #expect(count.withLock { $0 } == 0)
  }

  private func entry(_ level: FestiCoreLogLevel, _ category: FestiCoreLogCategory, _ message: String) -> FestiCoreLogEntry {
    FestiCoreLogEntry(level: level, category: category, message: message, file: "File.swift", function: "run()", line: 7)
  }
}
