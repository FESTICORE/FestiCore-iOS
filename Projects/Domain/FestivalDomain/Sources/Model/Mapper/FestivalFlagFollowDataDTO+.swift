//
//  FestivalFlagFollowDataDTO+.swift
//  FestivalDomain
//
//  Created by FestiCore on 10/31/26.
//

import FestivalDomainInterface

public extension FestivalFlagFollowDataDTO {
  func toDomain() -> FestivalFlagFollowResult {
    .init(flagID: flagId, isFollowing: following, followerCount: followerCount)
  }
}
