//
//  FestivalPackRepositoryInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 팩 변경 요약 서버 API
public protocol FestivalPackRepositoryInterface: Sendable {
  func packChanges(festivalID: String, fromVersion: Int) async throws -> FestivalPackChanges
}

public enum FestivalPackRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalPackRepositoryInterface { UnregisteredFestivalPackRepository() }
  public static var previewValue: any FestivalPackRepositoryInterface { testValue }
}

public extension DependencyValues {
  var festivalPackRepository: any FestivalPackRepositoryInterface {
    get { self[FestivalPackRepositoryDependency.self] }
    set { self[FestivalPackRepositoryDependency.self] = newValue }
  }
}

private struct UnregisteredFestivalPackRepository: FestivalPackRepositoryInterface {
  func packChanges(festivalID _: String, fromVersion _: Int) async throws -> FestivalPackChanges {
    reportIssue("festivalPackRepository.packChanges 미등록")
    throw FestivalPackError.notRegistered
  }
}
