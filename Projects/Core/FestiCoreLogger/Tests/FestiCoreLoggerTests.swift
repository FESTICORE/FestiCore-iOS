//
//  FestiCoreLoggerTests.swift
//  FestiCoreLogger
//
//  Created by FestiCore on 10/22/26.
//

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

  @Test("빌드 구성에 따른 최소 로그 레벨")
  func minimumLevel() {
    #if DEBUG
    #expect(FestiCoreLogger.minimumLevel == .debug)
    #else
    #expect(FestiCoreLogger.minimumLevel == .notice)
    #endif
  }
}
