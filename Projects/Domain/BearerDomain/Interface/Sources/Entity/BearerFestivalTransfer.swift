//
//  BearerFestivalTransfer.swift
//  BearerDomainInterface
//
//  Created by FestiCore on 11/26/26.
//

import Foundation

/// 깃발 축제 이동 한 건. 응답을 받지 못해 다시 보낼 때는 같은 값(같은 멱등키)을 쓴다.
public struct BearerFestivalTransferRequest: Sendable, Equatable {
  public let flagID: String
  public let fromFestivalID: String
  public let toFestivalID: String
  public let idempotencyKey: String

  public init(
    flagID: String,
    fromFestivalID: String,
    toFestivalID: String,
    idempotencyKey: String
  ) {
    self.flagID = flagID
    self.fromFestivalID = fromFestivalID
    self.toFestivalID = toFestivalID
    self.idempotencyKey = idempotencyKey
  }
}

/// 옮긴 결과. flagID · 이름 · 사진 · 팔로워는 그대로이고 계획 · 주로 있는 존 · 현장 상태는 서버가 비운다.
public struct BearerFestivalTransfer: Sendable, Equatable {
  public let flagID: String
  public let previousFestivalID: String
  public let festivalID: String
  public let profile: BearerFlagProfile

  public init(
    flagID: String,
    previousFestivalID: String,
    festivalID: String,
    profile: BearerFlagProfile
  ) {
    self.flagID = flagID
    self.previousFestivalID = previousFestivalID
    self.festivalID = festivalID
    self.profile = profile
  }
}
