//
//  MockFestivalFlagUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalFlagUseCase: FestivalFlagUseCaseInterface {
  private let liveBoardHandler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot
  private let setFollowingHandler:
    @Sendable (Bool, String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult

  public init(
    liveBoard: @escaping @Sendable (String) async throws -> FestivalLiveBoardSnapshot = { _ in
      reportIssue("festivalFlagUseCase.liveBoard 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    setFollowing: @escaping @Sendable (Bool, String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult = {
      _, _ throws(FestivalFlagFollowError) in
      reportIssue("festivalFlagUseCase.setFollowing 미등록")
      throw .unavailable
    }
  ) {
    self.liveBoardHandler = liveBoard
    self.setFollowingHandler = setFollowing
  }

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardHandler(festivalID)
  }

  public func setFollowing(
    _ following: Bool, flagID: String
  ) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    try await setFollowingHandler(following, flagID)
  }
}
