//
//  FestivalScheduleService.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 10/30/26.
//

import Dependencies
import Foundation

public protocol FestivalScheduleService: Sendable {
  func fetch(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule
  /// 내 일정 전체를 교체한다. `clientAt`은 축제마다 이전 요청보다 늦어야 한다.
  func replace(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule
}

public enum FestivalScheduleServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalScheduleService {
    EmptyFestivalScheduleService()
  }
}

public extension DependencyValues {
  var festivalScheduleService: any FestivalScheduleService {
    get { self[FestivalScheduleServiceDependency.self] }
    set { self[FestivalScheduleServiceDependency.self] = newValue }
  }
}

private struct EmptyFestivalScheduleService: FestivalScheduleService {
  func fetch(festivalID _: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    .init(setIDs: [])
  }

  func replace(
    festivalID _: String,
    setIDs: [String],
    clientAt _: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    .init(setIDs: setIDs)
  }
}
