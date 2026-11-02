//
//  FestivalScheduleUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

public struct FestivalScheduleUseCaseImpl: FestivalScheduleUseCaseInterface {
  @Dependency(\.festivalScheduleService) private var scheduleService

  public init() {}

  public func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.fetch(festivalID: festivalID)
  }

  public func saveMySchedule(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.replace(
      festivalID: festivalID,
      setIDs: setIDs,
      clientAt: clientAt
    )
  }
}
