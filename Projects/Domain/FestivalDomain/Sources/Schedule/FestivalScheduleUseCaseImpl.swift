//
//  FestivalScheduleUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

/// 사용자가 고른 공연 일정을 서버와 동기화한다.
public struct FestivalScheduleUseCaseImpl: FestivalScheduleUseCaseInterface {
  @Dependency(\.festivalScheduleService) private var scheduleService

  public init() {}

  /// 축제의 내 공연 일정을 서버에서 읽는다.
  public func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.fetch(festivalID: festivalID)
  }

  /// 선택한 공연 목록으로 내 일정을 교체한다.
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
