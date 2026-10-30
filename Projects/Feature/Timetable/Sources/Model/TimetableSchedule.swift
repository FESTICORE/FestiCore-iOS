//
//  TimetableSchedule.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

/// 하루 타임테이블. 시각은 그날 0시부터의 분이고, 자정을 넘기면 1440 이상이다.
public struct TimetableDay: Equatable, Identifiable, Sendable {
  public let id: String
  public var title: String
  public var stages: [TimetableStage]
  public var sets: [TimetableSet]

  public init(
    id: String,
    title: String,
    stages: [TimetableStage],
    sets: [TimetableSet]
  ) {
    self.id = id
    self.title = title
    self.stages = stages
    self.sets = sets
  }

  /// 시작 시각이 바뀐 공연 수
  public var changedCount: Int {
    sets.count { $0.previousStart != nil }
  }
}

public struct TimetableStage: Equatable, Identifiable, Sendable {
  public let id: String
  public var name: String

  public init(
    id: String,
    name: String
  ) {
    self.id = id
    self.name = name
  }
}

public struct TimetableSet: Equatable, Identifiable, Sendable {
  public let id: String
  public var artist: String
  public var stageID: String
  public var start: Int
  public var end: Int
  /// 바뀌기 전 시작 시각. 바뀌지 않았으면 nil이다.
  public var previousStart: Int?

  public init(
    id: String,
    artist: String,
    stageID: String,
    start: Int,
    end: Int,
    previousStart: Int? = nil
  ) {
    self.id = id
    self.artist = artist
    self.stageID = stageID
    self.start = start
    self.end = end
    self.previousStart = previousStart
  }

  func overlaps(_ other: TimetableSet) -> Bool {
    start < other.end && other.start < end
  }
}

/// 시간표 공개 전에 보여 줄 날짜별 라인업
public struct TimetableLineupDay: Equatable, Identifiable, Sendable {
  public let id: String
  public var title: String
  public var artists: [String]

  public init(
    id: String,
    title: String,
    artists: [String]
  ) {
    self.id = id
    self.title = title
    self.artists = artists
  }
}

/// 내 일정끼리 겹치는 구간
public struct TimetableOverlap: Equatable, Sendable {
  public var start: Int
  public var end: Int

  public var minutes: Int {
    end - start
  }
}

enum TimetableTime {
  /// 분을 `HH:mm`으로 바꾼다. 자정을 넘긴 시각은 다음날 시각으로 적는다.
  static func clock(_ minute: Int) -> String {
    let value = minute % (24 * 60)
    return String(format: "%02d:%02d", value / 60, value % 60)
  }

  static func range(
    _ start: Int,
    _ end: Int
  ) -> String {
    let crossesMidnight = start < 24 * 60 && end > 24 * 60
    return "\(clock(start))–\(crossesMidnight ? "다음날 " : "")\(clock(end))"
  }

  /// 바뀐 시작 시각을 "20분 미뤄짐"·"15분 당겨짐"으로 적는다.
  static func change(
    from previous: Int,
    to current: Int
  ) -> String {
    let delta = current - previous
    return delta > 0 ? "\(delta)분 미뤄짐" : "\(-delta)분 당겨짐"
  }
}
