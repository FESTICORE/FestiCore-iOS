//
//  FestivalFlagUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 깃발 화면이 쓰는 라이브 보드 조회와 깃발 팔로우.
///
/// `liveBoard`는 `FestivalLiveBoardUseCaseInterface.liveBoard`와 같은 서비스를 부른다. 깃발 화면이 한 계약만
/// 주입하도록 화면 단위로 나눈 것이다.
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
