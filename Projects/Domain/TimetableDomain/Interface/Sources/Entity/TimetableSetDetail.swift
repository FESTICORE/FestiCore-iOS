//
//  TimetableSetDetail.swift
//  TimetableDomainInterface
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

/// 공연 상세 시트에 보여 줄 정보
public struct TimetableSetDetail: Equatable, Sendable {
  public enum Status: Equatable, Sendable {
    case upcoming(minutes: Int)
    case live
    case ended
  }

  public var artist: String
  public var stage: String
  public var time: String
  public var status: Status
  public var isScheduled: Bool
  /// 시간이 겹치는 다른 내 일정 공연 중 가장 먼저 시작하는 공연
  public var overlap: TimetableSetOverlap?
  /// 바뀌기 전 시작 시각(`HH:mm`). 바뀌지 않았으면 nil이다.
  public var previousTime: String?
  public var change: String?
  /// 출연진 사진. 없으면 시트에 이름만 보인다.
  public var imageURL: URL?

  public init(
    artist: String,
    stage: String,
    time: String,
    status: Status,
    isScheduled: Bool,
    overlap: TimetableSetOverlap? = nil,
    previousTime: String? = nil,
    change: String? = nil,
    imageURL: URL? = nil
  ) {
    self.artist = artist
    self.stage = stage
    self.time = time
    self.status = status
    self.isScheduled = isScheduled
    self.overlap = overlap
    self.previousTime = previousTime
    self.change = change
    self.imageURL = imageURL
  }

  public var relativeTime: String {
    switch status {
    case let .upcoming(minutes) where minutes < 60:
      return "\(minutes)분 후"
    case let .upcoming(minutes):
      let hours = minutes / 60
      let rest = minutes % 60
      return rest == 0 ? "\(hours)시간 후" : "\(hours)시간 \(rest)분 후"
    case .live:
      return "공연 중"
    case .ended:
      return "종료"
    }
  }
}

public extension TimetableSetDetail.Status {
  /// 공연의 실제 시작·종료 시각과 현재 시각으로 진행 상태를 구한다.
  init(
    interval: DateInterval,
    now: Date
  ) {
    if now >= interval.end {
      self = .ended
    } else if now >= interval.start {
      self = .live
    } else {
      self = .upcoming(minutes: Int((interval.start.timeIntervalSince(now) / 60).rounded(.up)))
    }
  }
}

/// 상세 시트의 겹침 경고에 쓰는 다른 내 일정 공연
public struct TimetableSetOverlap: Equatable, Sendable {
  public var artist: String
  public var stage: String
  /// `HH:mm–HH:mm`
  public var time: String
  /// 겹치는 시간(분)
  public var minutes: Int

  public init(
    artist: String,
    stage: String,
    time: String,
    minutes: Int
  ) {
    self.artist = artist
    self.stage = stage
    self.time = time
    self.minutes = minutes
  }

  /// "크라잉버드(원더 스테이지 15:55–16:45)와 35분 겹쳐요"
  public var warning: String {
    "\(artist)(\(stage) \(time))\(particle) \(minutes)분 겹쳐요"
  }

  /// 이름 끝 글자가 한글이면 받침에 따라 `와`·`과`를 고르고, 아니면 `와`를 쓴다.
  /// 자모가 나뉜 이름도 같은 글자로 보도록 완성형으로 바꿔 판단한다.
  private var particle: String {
    guard let last = artist.precomposedStringWithCanonicalMapping.unicodeScalars.last,
          (0xAC00 ... 0xD7A3).contains(last.value) else { return "와" }
    return (last.value - 0xAC00) % 28 == 0 ? "와" : "과"
  }
}
