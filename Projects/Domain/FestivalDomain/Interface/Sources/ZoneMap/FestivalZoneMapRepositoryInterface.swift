//
//  FestivalZoneMapRepositoryInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies

/// 존 지도 서버 경계. 현재 발행 팩의 지도 버전만 조회한다(`GET festivals/:id/pack/version`).
public protocol FestivalZoneMapRepositoryInterface: Sendable {
  func latestMapVersion(festivalID: String) async throws -> String?
}

public enum FestivalZoneMapRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalZoneMapRepositoryInterface {
    return UnregisteredFestivalZoneMapRepository()
  }

  public static var previewValue: any FestivalZoneMapRepositoryInterface { return testValue }
}

public extension DependencyValues {
  var festivalZoneMapRepository: any FestivalZoneMapRepositoryInterface {
    get { self[FestivalZoneMapRepositoryDependency.self] }
    set { self[FestivalZoneMapRepositoryDependency.self] = newValue }
  }
}

/// 주입하지 않은 테스트·프리뷰 호출을 테스트 이슈로 기록하는 기본 Repository
private struct UnregisteredFestivalZoneMapRepository: FestivalZoneMapRepositoryInterface {
  func latestMapVersion(festivalID _: String) async throws -> String? {
    reportIssue("festivalZoneMapRepository.latestMapVersion 미등록")
    throw FestivalPackError.notRegistered
  }
}
