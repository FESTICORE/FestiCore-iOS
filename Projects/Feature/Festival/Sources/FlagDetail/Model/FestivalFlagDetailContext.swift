//
//  FestivalFlagDetailContext.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import Foundation

/// 깃발 상세가 부모에게서 받는 표시 입력. 계획 공연 ID를 받은 팩의 공연으로, 존 ID를 이름으로 바꾼다.
public struct FestivalFlagDetailContext: Equatable, Sendable {
  /// 계획 행에 보일 팩 공연.
  public struct Performance: Equatable, Sendable {
    public let artist: String
    public let stageName: String
    public let startsAt: Date
    public let endsAt: Date

    public init(
      artist: String,
      stageName: String,
      startsAt: Date,
      endsAt: Date
    ) {
      self.artist = artist
      self.stageName = stageName
      self.startsAt = startsAt
      self.endsAt = endsAt
    }
  }

  public var zoneNames: [String: String]
  public var performances: [String: Performance]
  public var mySetIDs: Set<String>
  public var hasSession: Bool

  public init(
    zoneNames: [String: String] = [:],
    performances: [String: Performance] = [:],
    mySetIDs: Set<String> = [],
    hasSession: Bool = false
  ) {
    self.zoneNames = zoneNames
    self.performances = performances
    self.mySetIDs = mySetIDs
    self.hasSession = hasSession
  }
}
