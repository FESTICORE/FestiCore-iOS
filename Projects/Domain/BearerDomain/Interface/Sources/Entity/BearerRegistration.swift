//
//  BearerRegistration.swift
//  BearerDomain
//
//  Created by FestiCore on 11/12/26.
//

import Foundation

/// 코드 없는 기수 등록 한 건. 다시 보낼 때는 같은 멱등키와 같은 본문을 쓴다.
public struct BearerRegisterRequest: Sendable, Equatable {
  public let festivalID: String
  public let change: BearerProfileChange
  public let idempotencyKey: String

  public init(
    festivalID: String,
    change: BearerProfileChange,
    idempotencyKey: String
  ) {
    self.festivalID = festivalID
    self.change = change
    self.idempotencyKey = idempotencyKey
  }
}

/// 내가 원래 기수 또는 공동 기수인 깃발
public struct BearerOwnedFlag: Sendable, Equatable, Identifiable {
  public var id: String { return profile.id }
  public let festivalID: String
  /// 처음 깃발을 만든 원래 기수인지
  public let isOwner: Bool
  public let joinedAt: Date?
  public let profile: BearerFlagProfile
  /// 서버가 상태를 주지 않았거나 모르는 값이면 nil이다.
  public let lifecycle: BearerFlagLifecycle?
  public let isHidden: Bool

  public init(
    festivalID: String,
    isOwner: Bool,
    joinedAt: Date?,
    profile: BearerFlagProfile,
    lifecycle: BearerFlagLifecycle?,
    isHidden: Bool
  ) {
    self.festivalID = festivalID
    self.isOwner = isOwner
    self.joinedAt = joinedAt
    self.profile = profile
    self.lifecycle = lifecycle
    self.isHidden = isHidden
  }
}

/// 내 대표 깃발(계정당 하나)
public struct BearerPinnedFlag: Sendable, Equatable {
  public let flagID: String
  public let name: String
  public let festivalID: String?
  public let thumbnailURL: URL?

  public init(
    flagID: String,
    name: String,
    festivalID: String?,
    thumbnailURL: URL?
  ) {
    self.flagID = flagID
    self.name = name
    self.festivalID = festivalID
    self.thumbnailURL = thumbnailURL
  }
}

/// 내가 팔로우한 깃발(최근 팔로우순). 잠금화면에 보일 대표 깃발 후보다.
public struct BearerFollowedFlag: Sendable, Equatable, Identifiable {
  public let flagID: String
  public let festivalID: String
  public let name: String
  public let thumbnailURL: URL?
  /// 팔로우 시각. 형식을 읽지 못하면 nil이다.
  public let followedAt: Date?

  public var id: String { return flagID }

  public init(
    flagID: String,
    festivalID: String,
    name: String,
    thumbnailURL: URL?,
    followedAt: Date?
  ) {
    self.flagID = flagID
    self.festivalID = festivalID
    self.name = name
    self.thumbnailURL = thumbnailURL
    self.followedAt = followedAt
  }
}

/// 깃발을 만들 페스티벌 후보(S14 D). 받은 팩이 있으면 존과 팩 받기 권유가 달라진다.
public struct BearerFestivalOption: Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  /// 예) `11/20-22`. 날짜를 모르면 nil이다.
  public let dateText: String?
  public let hasPack: Bool

  public init(
    id: String,
    name: String,
    dateText: String?,
    hasPack: Bool
  ) {
    self.id = id
    self.name = name
    self.dateText = dateText
    self.hasPack = hasPack
  }

  /// 목록 한 줄 문구. 예) `원더리벳 2026 · 11/20-22`
  public var title: String {
    guard let dateText else { return name }
    return "\(name) · \(dateText)"
  }
}
