//
//  FlagFollowData.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public struct FlagFollowData: Equatable, Sendable {
  public let flagID: String
  /// 팔로우하면 true, 해제하면 false.
  public let isFollowing: Bool

  public init(flagID: String, isFollowing: Bool) {
    self.flagID = flagID
    self.isFollowing = isFollowing
  }
}
