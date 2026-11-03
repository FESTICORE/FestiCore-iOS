//
//  MockFestivalReceivedPackUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalReceivedPackUseCase: FestivalReceivedPackUseCaseInterface {
  private let receivedPacksHandler: @Sendable () async throws -> [FestivalReceivedPack]
  private let refreshReceivedPacksHandler: @Sendable () async throws -> [FestivalReceivedPack]

  public init(
    receivedPacks: @escaping @Sendable () async throws -> [FestivalReceivedPack] = {
      reportIssue("festivalReceivedPackUseCase.receivedPacks 미등록")
      throw FestivalPackError.notRegistered
    },
    refreshReceivedPacks: @escaping @Sendable () async throws -> [FestivalReceivedPack] = {
      reportIssue("festivalReceivedPackUseCase.refreshReceivedPacks 미등록")
      throw FestivalPackError.notRegistered
    }
  ) {
    self.receivedPacksHandler = receivedPacks
    self.refreshReceivedPacksHandler = refreshReceivedPacks
  }

  public func receivedPacks() async throws -> [FestivalReceivedPack] {
    try await receivedPacksHandler()
  }

  public func refreshReceivedPacks() async throws -> [FestivalReceivedPack] {
    try await refreshReceivedPacksHandler()
  }
}
