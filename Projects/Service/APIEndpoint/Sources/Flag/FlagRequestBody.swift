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

  public init(
    name: String,
    bio: String?,
    tags: [String],
    planVisible: Bool,
    homeZoneId: String?
  ) {
    self.name = name
    self.bio = bio
    self.tags = tags
    self.planVisible = planVisible
    self.homeZoneId = homeZoneId
  }

  private enum CodingKeys: String, CodingKey {
    case name, bio, tags, planVisible, homeZoneId
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(bio, forKey: .bio)
    try container.encode(tags, forKey: .tags)
    try container.encode(planVisible, forKey: .planVisible)
    try container.encode(homeZoneId, forKey: .homeZoneId)
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
