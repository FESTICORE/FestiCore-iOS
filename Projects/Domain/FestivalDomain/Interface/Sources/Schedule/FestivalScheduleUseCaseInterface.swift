//
//  FestivalScheduleUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import Foundation

/// 타임테이블의 내 일정을 서버에서 읽고 저장한다.
public protocol FestivalScheduleUseCaseInterface: Sendable {
  /// 축제에서 사용자가 고른 공연 일정을 서버에서 읽는다.
  func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule
  /// 내 일정 전체를 교체한다. `clientAt`은 축제마다 이전 요청보다 늦어야 한다.
  func saveMySchedule(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule
}

public enum FestivalScheduleUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalScheduleUseCaseInterface { MockFestivalScheduleUseCase() }
  public static var previewValue: any FestivalScheduleUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalScheduleUseCase: any FestivalScheduleUseCaseInterface {
    get { self[FestivalScheduleUseCaseDependency.self] }
    set { self[FestivalScheduleUseCaseDependency.self] = newValue }
  }
}
