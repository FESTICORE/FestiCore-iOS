//
//  FestivalFlagUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

/// 깃발 화면의 라이브 조회와 팔로우 요청을 연결한다.
public struct FestivalFlagUseCaseImpl: FestivalFlagUseCaseInterface {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService
  @Dependency(\.festivalFlagFollowService) private var followService

  public init() {}

  /// 선택한 축제의 최신 라이브 보드를 조회한다.
  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }

  /// 깃발 팔로우 상태를 서버에 저장한다.
  public func setFollowing(
    _ following: Bool, flagID: String
  ) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    try await followService.setFollowing(following, flagID: flagID)
  }
}
