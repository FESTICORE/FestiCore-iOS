//
//  FestiCoreLogSink.swift
//  FestiCoreLogger
//
//  Created by FestiCore on 11/3/26.
//

/// OSLog 밖으로 로그를 보내는 출력 대상. Core는 수집 SDK를 모르고, SDK를 아는 모듈이 구현해 등록한다.
public protocol FestiCoreLogSink: Sendable {
  func send(_ entry: FestiCoreLogEntry)
}

public struct FestiCoreLogEntry: Equatable, Sendable {
  public let level: FestiCoreLogLevel
  public let category: FestiCoreLogCategory
  public let message: String
  public let file: String
  public let function: String
  public let line: Int

  public init(
    level: FestiCoreLogLevel,
    category: FestiCoreLogCategory,
    message: String,
    file: String,
    function: String,
    line: Int
  ) {
    self.level = level
    self.category = category
    self.message = message
    self.file = file
    self.function = function
    self.line = line
  }
}
