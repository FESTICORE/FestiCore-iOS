//
//  FestivalFlagDetail.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

import Foundation

/// 팔로워가 보는 깃발 상세(S05). 계획은 공연 ID만 담고, 시간·무대는 화면이 받은 팩에서 찾는다.
public struct FestivalFlagDetail: Equatable, Sendable {
  /// 깃발의 하루 상태.
  public enum Status: String, Equatable, Sendable {
    case scheduled
    case active
    case resting
    case ended
  }

  /// 기수가 알린 지금 하는 일.
  public enum Activity: String, Equatable, Sendable {
    case slam
    case sing
    case train
    case calm
    case resting
  }

  public let id: String
  public let name: String
  public let thumbnailURL: URL?
  public let photoURL: URL?
  public let tags: [String]
  public let bio: String?
  public let followerCount: Int
  /// 기수가 오늘 계획을 팔로워에게 보이기로 했는지. false면 `planSetIDs`는 비어 있다.
  public let isPlanVisible: Bool
  public let planSetIDs: [String]
  public let homeZoneID: String?
  public let status: Status
  public let zoneID: String?
  public let activity: Activity?
  public let statusUpdatedAt: Date
  /// 익명 조회면 nil.
  public let isFollowing: Bool?
  /// 익명 조회면 nil.
  public let isBearer: Bool?
  /// 내 잠금화면 대표 깃발인지. 익명 조회이거나 서버가 값을 주지 않으면 nil.
  public let isPinned: Bool?
  /// 숨김 처리된 깃발. 기수 본인에게만 내려온다.
  public let isHidden: Bool

  public init(
    id: String,
    name: String,
    thumbnailURL: URL?,
    photoURL: URL?,
    tags: [String],
    bio: String?,
    followerCount: Int,
    isPlanVisible: Bool,
    planSetIDs: [String],
    homeZoneID: String?,
    status: Status,
    zoneID: String?,
    activity: Activity?,
    statusUpdatedAt: Date,
    isFollowing: Bool?,
    isBearer: Bool?,
    isPinned: Bool? = nil,
    isHidden: Bool
  ) {
    self.id = id
    self.name = name
    self.thumbnailURL = thumbnailURL
    self.photoURL = photoURL
    self.tags = tags
    self.bio = bio
    self.followerCount = followerCount
    self.isPlanVisible = isPlanVisible
    self.planSetIDs = planSetIDs
    self.homeZoneID = homeZoneID
    self.status = status
    self.zoneID = zoneID
    self.activity = activity
    self.statusUpdatedAt = statusUpdatedAt
    self.isFollowing = isFollowing
    self.isBearer = isBearer
    self.isPinned = isPinned
    self.isHidden = isHidden
  }
}
