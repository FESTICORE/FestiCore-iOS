//
//  TimetableDay.swift
//  TimetableDomainInterface
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

/// 하루 타임테이블. 시각은 그날 0시부터의 분이고, 자정을 넘기면 1440 이상이다.
public struct TimetableDay: Equatable, Identifiable, Sendable {
  public let id: String
  public var title: String
  /// 그날 0시(Asia/Seoul). 공연의 실제 시각은 여기에 분을 더해 구한다.
  public var date: Date
  public var stages: [TimetableStage]
  public var sets: [TimetableSet]

  public init(
    id: String,
    title: String,
    date: Date,
    stages: [TimetableStage],
    sets: [TimetableSet]
  ) {
    self.id = id
    self.title = title
    self.date = date
    self.stages = stages
    self.sets = sets
  }

  /// 공연의 실제 시작·종료 시각
  public func interval(of set: TimetableSet) -> DateInterval {
    DateInterval(
      start: date.addingTimeInterval(TimeInterval(set.start * 60)),
      end: date.addingTimeInterval(TimeInterval(set.end * 60))
    )
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
  /// 출연진 사진. 없으면 nil이다.
  public var imageURL: URL?

  public init(
    id: String,
    artist: String,
    stageID: String,
    start: Int,
    end: Int,
    previousStart: Int? = nil,
    imageURL: URL? = nil
  ) {
    self.id = id
    self.artist = artist
    self.stageID = stageID
    self.start = start
    self.end = end
    self.previousStart = previousStart
    self.imageURL = imageURL
  }

  func overlaps(_ other: TimetableSet) -> Bool {
    start < other.end && other.start < end
  }
}

public extension TimetableDay {
  /// 그날 0시부터의 분을 `HH:mm`으로 적는다. 자정을 넘긴 시각은 다음날 시각으로 적는다.
  static func clock(_ minute: Int) -> String {
    let value = minute % (24 * 60)
    return String(format: "%02d:%02d", value / 60, value % 60)
  }
}

public extension TimetableSet {
  /// `HH:mm–HH:mm`. 자정을 넘기면 끝 시각 앞에 "다음날"을 붙인다.
  var timeRange: String {
    let crossesMidnight = start < 24 * 60 && end > 24 * 60
    return "\(TimetableDay.clock(start))–\(crossesMidnight ? "다음날 " : "")\(TimetableDay.clock(end))"
  }

  /// 공연 시각과 길이를 "17:00–17:50 · 50분"으로 적는다.
  var timeRangeWithDuration: String {
    "\(timeRange) · \(end - start)분"
  }

  /// 바뀌기 전 시작 시각(`HH:mm`). 바뀌지 않았으면 nil이다.
  var previousTime: String? {
    previousStart.map(TimetableDay.clock)
  }

  /// 바뀐 시작 시각을 "20분 미뤄짐"·"15분 당겨짐"으로 적는다. 바뀌지 않았으면 nil이다.
  var startChange: String? {
    previousStart.map { previous in
      let delta = start - previous
      return delta > 0 ? "\(delta)분 미뤄짐" : "\(-delta)분 당겨짐"
    }
  }
}
