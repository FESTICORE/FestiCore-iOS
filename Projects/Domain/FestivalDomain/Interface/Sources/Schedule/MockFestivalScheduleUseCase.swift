//
//  MockFestivalScheduleUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import Foundation

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalScheduleUseCase: FestivalScheduleUseCaseInterface {
  private let myScheduleHandler: @Sendable (String) async throws(FestivalScheduleError) -> FestivalSchedule
  private let saveMyScheduleHandler: @Sendable (String, [String], Date) async throws(FestivalScheduleError) -> FestivalSchedule

  public init(
    mySchedule: @escaping @Sendable (String) async throws(FestivalScheduleError) -> FestivalSchedule = {
      _ throws(FestivalScheduleError) in
      reportIssue("festivalScheduleUseCase.mySchedule 미등록")
      throw .unavailable
    },
    saveMySchedule: @escaping @Sendable (String, [String], Date) async throws(FestivalScheduleError) -> FestivalSchedule = {
      _, _, _ throws(FestivalScheduleError) in
      reportIssue("festivalScheduleUseCase.saveMySchedule 미등록")
      throw .unavailable
    }
  ) {
    self.myScheduleHandler = mySchedule
    self.saveMyScheduleHandler = saveMySchedule
  }

  public func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await myScheduleHandler(festivalID)
  }

  public func saveMySchedule(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await saveMyScheduleHandler(festivalID, setIDs, clientAt)
  }
}
