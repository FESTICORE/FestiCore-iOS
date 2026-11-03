//
//  FestivalFlagUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

public struct FestivalFlagUseCaseImpl: FestivalFlagUseCaseInterface {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService
  @Dependency(\.festivalFlagFollowService) private var followService

  public init() {}

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }

  public func setFollowing(
    _ following: Bool, flagID: String
  ) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    try await followService.setFollowing(following, flagID: flagID)
  }
}
