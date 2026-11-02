//
//  FestivalLiveBoardUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 라이브 보드와 그 축제의 내 일정을 불러온다.
public protocol FestivalLiveBoardUseCaseInterface: Sendable {
  func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot
  func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule
}

public enum FestivalLiveBoardUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalLiveBoardUseCaseInterface { MockFestivalLiveBoardUseCase() }
  public static var previewValue: any FestivalLiveBoardUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalLiveBoardUseCase: any FestivalLiveBoardUseCaseInterface {
    get { self[FestivalLiveBoardUseCaseDependency.self] }
    set { self[FestivalLiveBoardUseCaseDependency.self] = newValue }
  }
}
