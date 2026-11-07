//
//  FestivalFlagDetailContext.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import Foundation

/// 깃발 상세가 부모에게서 받는 표시 입력. 계획 공연 ID를 받은 팩의 공연으로, 존 ID를 이름으로 바꾸고 계정·대표 깃발을 알린다.
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
  /// 로그인한 계정 ID. 계정이 바뀌면 상세가 계정별 값(팔로우·대표 깃발)을 다시 받는다.
  public var accountID: String?
  /// 라이브 보드가 알려 준 내 잠금화면 대표 깃발. 상세 응답에 대표 여부가 없을 때 쓴다.
  public var pinnedFlagID: String?

  public init(
    zoneNames: [String: String] = [:],
    performances: [String: Performance] = [:],
    mySetIDs: Set<String> = [],
    hasSession: Bool = false,
    accountID: String? = nil,
    pinnedFlagID: String? = nil
  ) {
    self.zoneNames = zoneNames
    self.performances = performances
    self.mySetIDs = mySetIDs
    self.hasSession = hasSession
    self.accountID = accountID
    self.pinnedFlagID = pinnedFlagID
  }
}
