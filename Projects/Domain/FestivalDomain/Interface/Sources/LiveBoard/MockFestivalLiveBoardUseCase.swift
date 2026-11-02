//
//  MockFestivalLiveBoardUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalLiveBoardUseCase: FestivalLiveBoardUseCaseInterface {
  private let liveBoardHandler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot
  private let myScheduleHandler: @Sendable (String) async throws(FestivalScheduleError) -> FestivalSchedule

  public init(
    liveBoard: @escaping @Sendable (String) async throws -> FestivalLiveBoardSnapshot = { _ in
      reportIssue("festivalLiveBoardUseCase.liveBoard 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    mySchedule: @escaping @Sendable (String) async throws(FestivalScheduleError) -> FestivalSchedule = {
      _ throws(FestivalScheduleError) in
      reportIssue("festivalLiveBoardUseCase.mySchedule 미등록")
      throw .unavailable
    }
  ) {
    self.liveBoardHandler = liveBoard
    self.myScheduleHandler = mySchedule
  }

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardHandler(festivalID)
  }

  public func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await myScheduleHandler(festivalID)
  }
}
