//
//  FlagRequestBody.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// `POST flags/:flagId/status` 본문. 값이 없는 키는 보내지 않는다.
public struct FlagStatusBody: Encodable, Sendable, Equatable {
  public let clientAt: String
  public let zoneId: String?
  public let activity: String?
  public let status: String?
  public let restart: Bool?

  public init(
    clientAt: String,
    zoneId: String? = nil,
    activity: String? = nil,
    status: String? = nil,
    restart: Bool? = nil
  ) {
    self.clientAt = clientAt
    self.zoneId = zoneId
    self.activity = activity
    self.status = status
    self.restart = restart
  }
}

/// `PATCH flags/:flagId` 본문. 화면의 전체 프로필을 보내며 비운 소개·존은 null로 지운다.
public struct FlagProfileBody: Encodable, Sendable, Equatable {
  public let name: String
  public let bio: String?
  public let tags: [String]
  public let planVisible: Bool
  public let homeZoneId: String?
  /// 오늘 계획(셋 ID). nil이면 보내지 않아 서버 값을 그대로 둔다.
  public let plan: [String]?

  public init(
    name: String,
    bio: String?,
    tags: [String],
    planVisible: Bool,
    homeZoneId: String?,
    plan: [String]? = nil
  ) {
    self.name = name
    self.bio = bio
    self.tags = tags
    self.planVisible = planVisible
    self.homeZoneId = homeZoneId
    self.plan = plan
  }

  private enum CodingKeys: String, CodingKey {
    case name, bio, tags, planVisible, homeZoneId, plan
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      name,
      forKey: .name
    )
    try container.encode(
      bio,
      forKey: .bio
    )
    try container.encode(
      tags,
      forKey: .tags
    )
    try container.encode(
      planVisible,
      forKey: .planVisible
    )
    try container.encode(
      homeZoneId,
      forKey: .homeZoneId
    )
    try container.encodeIfPresent(
      plan,
      forKey: .plan
    )
  }
}

/// `POST bearer/claim` 본문
public struct BearerClaimBody: Encodable, Sendable, Equatable {
  public let festivalId: String
  public let code: String

  public init(
    festivalId: String,
    code: String
  ) {
    self.festivalId = festivalId
    self.code = code
  }
}

/// `POST bearer/register` 본문. 값이 없는 키(소개·존·계획)는 보내지 않는다.
public struct BearerRegisterBody: Encodable, Sendable, Equatable {
  public let festivalId: String
  public let name: String
  public let bio: String?
  public let tags: [String]
  public let planVisible: Bool
  public let homeZoneId: String?
  public let plan: [String]?

  public init(
    festivalId: String,
    name: String,
    bio: String?,
    tags: [String],
    planVisible: Bool,
    homeZoneId: String?,
    plan: [String]? = nil
  ) {
    self.festivalId = festivalId
    self.name = name
    self.bio = bio
    self.tags = tags
    self.planVisible = planVisible
    self.homeZoneId = homeZoneId
    self.plan = plan
  }
}

/// `GET me/bearer-flags` 쿼리. 페스티벌이 없으면 키를 보내지 않는다.
public struct BearerFlagsQuery: Encodable, Sendable, Equatable {
  public let festivalId: String?

  public init(festivalId: String? = nil) {
    self.festivalId = festivalId
  }
}

/// `GET me/follows` 쿼리. 페스티벌이 없으면 키를 보내지 않는다.
public struct FlagFollowsQuery: Encodable, Sendable, Equatable {
  public let festivalId: String?

  public init(festivalId: String? = nil) {
    self.festivalId = festivalId
  }
}

/// `POST flags/:flagId/report` 본문. 메모가 없으면 키를 보내지 않는다.
public struct FlagReportBody: Encodable, Sendable, Equatable {
  public let reason: String
  public let note: String?

  public init(
    reason: String,
    note: String? = nil
  ) {
    self.reason = reason
    self.note = note
  }
}

/// `PUT me/pinned-flag` 본문. 해제할 때도 `flagId: null`을 명시해 보낸다.
public struct PinnedFlagBody: Encodable, Sendable, Equatable {
  public let flagId: String?

  public init(flagId: String?) {
    self.flagId = flagId
  }

  private enum CodingKeys: String, CodingKey {
    case flagId
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      flagId,
      forKey: .flagId
    )
  }
}
