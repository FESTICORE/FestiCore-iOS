//
//  FestivalLiveBoardUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 라이브 보드 화면이 쓰는 라이브 보드 조회. 내 일정은 `FestivalScheduleUseCaseInterface`를 쓴다.
///
/// 깃발 화면의 `FestivalFlagUseCaseInterface.liveBoard`와 같은 서비스를 부르지만, UseCase는 화면이 하는 일
/// 단위로 묶는다. 라이브 보드 화면은 이 계약만, 깃발 화면은 깃발 계약만 주입해 서로의 동작(팔로우 등)을 받지 않는다.
public protocol FestivalLiveBoardUseCaseInterface: Sendable {
  func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot
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
