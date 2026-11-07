//
//  FestivalFlagDetailUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies

/// 깃발 상세 화면이 쓰는 조회 계약.
public protocol FestivalFlagDetailUseCaseInterface: Sendable {
  /// 깃발 프로필·현장 상태·오늘 계획과 팔로우 여부를 조회한다.
  func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail
}

public enum FestivalFlagDetailUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalFlagDetailUseCaseInterface { return MockFestivalFlagDetailUseCase() }
  public static var previewValue: any FestivalFlagDetailUseCaseInterface { return testValue }
}

public extension DependencyValues {
  var festivalFlagDetailUseCase: any FestivalFlagDetailUseCaseInterface {
    get { return self[FestivalFlagDetailUseCaseDependency.self] }
    set { self[FestivalFlagDetailUseCaseDependency.self] = newValue }
  }
}
