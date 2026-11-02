//
//  FestivalFlagUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 깃발 화면이 쓰는 라이브 보드 조회와 깃발 팔로우.
public protocol FestivalFlagUseCaseInterface: Sendable {
  func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot
  func setFollowing(_ following: Bool, flagID: String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult
}

public enum FestivalFlagUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalFlagUseCaseInterface { MockFestivalFlagUseCase() }
  public static var previewValue: any FestivalFlagUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalFlagUseCase: any FestivalFlagUseCaseInterface {
    get { self[FestivalFlagUseCaseDependency.self] }
    set { self[FestivalFlagUseCaseDependency.self] = newValue }
  }
}
