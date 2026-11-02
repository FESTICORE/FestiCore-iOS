//
//  BearerClaim.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 기수 코드 등록 결과
public struct BearerClaim: Sendable, Equatable {
  public let flagID: String
  public let profile: BearerFlagProfile
  /// 이 사용자가 깃발을 새로 만든 원래 기수인지
  public let isNew: Bool
  public let coBearerIDs: [String]

  public init(flagID: String, profile: BearerFlagProfile, isNew: Bool, coBearerIDs: [String]) {
    self.flagID = flagID
    self.profile = profile
    self.isNew = isNew
    self.coBearerIDs = coBearerIDs
  }
}

/// 공동 기수 초대 코드
public struct BearerInvite: Sendable, Equatable {
  public let code: String
  public let expiresAt: Date

  public init(code: String, expiresAt: Date) {
    self.code = code
    self.expiresAt = expiresAt
  }
}

/// 업로드한 깃발 사진의 주소
public struct BearerFlagPhoto: Sendable, Equatable {
  public let photoURL: URL?
  public let thumbnailURL: URL?

  public init(photoURL: URL?, thumbnailURL: URL?) {
    self.photoURL = photoURL
    self.thumbnailURL = thumbnailURL
  }
}

/// 깃발 프로필 화면이 저장하는 값. 비운 소개·존은 서버에서 지운다.
public struct BearerProfileChange: Sendable, Equatable {
  public let name: String
  public let bio: String?
  public let tags: [BearerFlagTag]
  public let planVisible: Bool
  public let homeZoneID: String?

  public init(name: String, bio: String?, tags: [BearerFlagTag], planVisible: Bool, homeZoneID: String?) {
    self.name = name
    self.bio = bio
    self.tags = tags
    self.planVisible = planVisible
    self.homeZoneID = homeZoneID
  }
}
