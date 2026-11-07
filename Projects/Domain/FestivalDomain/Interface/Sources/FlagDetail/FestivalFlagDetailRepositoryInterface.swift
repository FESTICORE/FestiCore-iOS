//
//  FestivalFlagDetailRepositoryInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies

/// 공개 깃발 상세 통신을 정의한다. 로그인 상태면 팔로우·기수 여부를 함께 받는다.
public protocol FestivalFlagDetailRepositoryInterface: Sendable {
  func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail
}

public enum FestivalFlagDetailRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalFlagDetailRepositoryInterface {
    return UnregisteredFestivalFlagDetailRepository()
  }
  public static var previewValue: any FestivalFlagDetailRepositoryInterface { return testValue }
}

public extension DependencyValues {
  var festivalFlagDetailRepository: any FestivalFlagDetailRepositoryInterface {
    get { return self[FestivalFlagDetailRepositoryDependency.self] }
    set { self[FestivalFlagDetailRepositoryDependency.self] = newValue }
  }
}

/// 저장소가 주입되지 않은 상세 조회를 테스트 오류로 알린다.
private struct UnregisteredFestivalFlagDetailRepository: FestivalFlagDetailRepositoryInterface {
  func detail(flagID _: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    reportIssue("festivalFlagDetailRepository.detail 미등록")
    throw .unavailable
  }
}
