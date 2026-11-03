//
//  TimetableOverlap.swift
//  TimetableDomainInterface
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

/// 내 일정끼리 겹치는 구간
public struct TimetableOverlap: Equatable, Sendable {
  public var start: Int
  public var end: Int

  public init(
    start: Int,
    end: Int
  ) {
    self.start = start
    self.end = end
  }

  public var minutes: Int {
    end - start
  }
}
