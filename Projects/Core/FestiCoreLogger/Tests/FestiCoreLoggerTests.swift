//
//  FestiCoreLoggerTests.swift
//  FestiCoreLogger
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import os
import OSLog
import Testing
@testable import FestiCoreLogger

@Suite("FestiCoreLogger")
struct FestiCoreLoggerTests {
  @Test("로그 레벨의 심각도와 OSLog 매핑")
  func levelMapping() {
    #expect(FestiCoreLogLevel.allCases.sorted() == [.debug, .info, .notice, .error, .fault])
    #expect(FestiCoreLogLevel.notice.osLogType == .default)
    #expect(FestiCoreLogLevel.error.osLogType == .error)
    #expect(FestiCoreLogLevel.fault.osLogType == .fault)
  }

  @Test("앱 전용 카테고리를 포함한 안정적인 로그 카테고리")
  func categories() {
    #expect(FestiCoreLogCategory.allCases.map(\.rawValue) == [
      "app", "network", "auth", "navigation", "storage", "ui", "festival"
    ])
  }

  @Test("등록한 출력 대상에는 info 이상만 전달한다")
  func sinkReceivesInfoAndAbove() {
    let marker = UUID().uuidString
    let sink = RecordingLogSink()
    FestiCoreLogger.addSink(sink)
    defer { FestiCoreLogger.removeAllSinks() }

    FestiCoreLogger.debug("debug \(marker)", category: .app)
    FestiCoreLogger.info("info \(marker)", category: .auth)
    FestiCoreLogger.error("error \(marker)", category: .festival)

    let entries = sink.entries.withLock { $0 }.filter { $0.message.hasSuffix(marker) }
    #if DEBUG
    #expect(entries.map(\.level) == [.info, .error])
    #expect(entries.map(\.category) == [.auth, .festival])
    #else
    // 릴리스는 OSLog 최소 레벨(notice)부터 남는다.
    #expect(entries.map(\.level) == [.error])
    #endif
    #expect(entries.last?.file == "FestiCoreLoggerTests.swift")
  }

  @Test("빌드 구성에 따른 최소 로그 레벨")
  func minimumLevel() {
    #if DEBUG
    #expect(FestiCoreLogger.minimumLevel == .debug)
    #else
    #expect(FestiCoreLogger.minimumLevel == .notice)
    #endif
  }
}

private final class RecordingLogSink: FestiCoreLogSink {
  let entries = OSAllocatedUnfairLock<[FestiCoreLogEntry]>(initialState: [])

  func send(_ entry: FestiCoreLogEntry) {
    entries.withLock { $0.append(entry) }
  }
}
