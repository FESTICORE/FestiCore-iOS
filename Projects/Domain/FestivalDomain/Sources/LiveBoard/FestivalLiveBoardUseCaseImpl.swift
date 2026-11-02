//
//  FestivalLiveBoardUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

public struct FestivalLiveBoardUseCaseImpl: FestivalLiveBoardUseCaseInterface {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService
  @Dependency(\.festivalScheduleService) private var scheduleService

  public init() {}

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }

  public func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.fetch(festivalID: festivalID)
  }
}
