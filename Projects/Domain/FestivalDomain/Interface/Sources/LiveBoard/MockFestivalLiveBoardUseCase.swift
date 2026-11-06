//
//  MockFestivalLiveBoardUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import Foundation

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalLiveBoardUseCase: FestivalLiveBoardUseCaseInterface {
  private let liveBoardHandler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot

  public init(
    liveBoard: @escaping @Sendable (String) async throws -> FestivalLiveBoardSnapshot = { _ in
      reportIssue("festivalLiveBoardUseCase.liveBoard 미등록")
      throw FestivalUseCaseNotRegistered()
    }
  ) {
    self.liveBoardHandler = liveBoard
  }

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    return try await liveBoardHandler(festivalID)
  }
}
