//
//  BearerFlag.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 현장 활동. 서버 `slam·sing·train·calm`과 같다.
public enum BearerActivity: String, Sendable, Equatable, CaseIterable {
  case slam
  case sing
  case train
  case calm
}

/// 깃발 성향 태그. 서버 `slam·sing·train·calm·newbie`와 같다.
public enum BearerFlagTag: String, Sendable, Equatable, CaseIterable {
  case slam
  case sing
  case train
  case calm
  case newbie
}

/// 깃발의 하루 상태
public enum BearerFlagLifecycle: String, Sendable, Equatable {
  case scheduled
  case active
  case resting
  case ended
}

public struct BearerFlagStatus: Sendable, Equatable {
  public let flagID: String
  public let lifecycle: BearerFlagLifecycle
  public let zoneID: String?
  /// 쉬는 중이면 서버가 `resting`을 보내므로 nil이다.
  public let activity: BearerActivity?
  public let updatedAt: Date
  /// 마지막으로 바꾼 기수(공동 기수 포함). 관리자 변경·변경 전이면 nil이다.
  public let updatedBy: BearerCoBearer?

  public init(
    flagID: String,
    lifecycle: BearerFlagLifecycle,
    zoneID: String?,
    activity: BearerActivity?,
    updatedAt: Date,
    updatedBy: BearerCoBearer? = nil
  ) {
    self.flagID = flagID
    self.lifecycle = lifecycle
    self.zoneID = zoneID
    self.activity = activity
    self.updatedAt = updatedAt
    self.updatedBy = updatedBy
  }
}

public struct BearerFlagProfile: Sendable, Equatable {
  public let id: String
  public let name: String
  public let photoURL: URL?
  public let thumbnailURL: URL?
  public let tags: [BearerFlagTag]
  public let bio: String?
  public let followerCount: Int
  public let planVisible: Bool
  public let plan: [String]
  public let homeZoneID: String?

  public init(
    id: String,
    name: String,
    photoURL: URL? = nil,
    thumbnailURL: URL? = nil,
    tags: [BearerFlagTag] = [],
    bio: String? = nil,
    followerCount: Int = 0,
    planVisible: Bool = true,
    plan: [String] = [],
    homeZoneID: String? = nil
  ) {
    self.id = id
    self.name = name
    self.photoURL = photoURL
    self.thumbnailURL = thumbnailURL
    self.tags = tags
    self.bio = bio
    self.followerCount = followerCount
    self.planVisible = planVisible
    self.plan = plan
    self.homeZoneID = homeZoneID
  }
}

public struct BearerCoBearer: Sendable, Equatable, Identifiable {
  public let userID: String
  public let nickname: String

  public var id: String { userID }

  public init(userID: String, nickname: String) {
    self.userID = userID
    self.nickname = nickname
  }
}

/// `GET flags/:flagId/bearer` 응답. 기수 보드가 그리는 값이다.
public struct BearerBoard: Sendable, Equatable {
  public let profile: BearerFlagProfile
  public let status: BearerFlagStatus
  public let followerCount: Int
  public let coBearers: [BearerCoBearer]
  public let hidden: Bool
  public let restartUsedToday: Bool

  public init(
    profile: BearerFlagProfile,
    status: BearerFlagStatus,
    followerCount: Int,
    coBearers: [BearerCoBearer] = [],
    hidden: Bool = false,
    restartUsedToday: Bool = false
  ) {
    self.profile = profile
    self.status = status
    self.followerCount = followerCount
    self.coBearers = coBearers
    self.hidden = hidden
    self.restartUsedToday = restartUsedToday
  }
}
