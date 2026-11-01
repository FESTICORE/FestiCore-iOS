//
//  FestivalFlagFollowService.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 10/31/26.
//

import Dependencies
import Foundation

public protocol FestivalFlagFollowService: Sendable {
  func setFollowing(_ following: Bool, flagID: String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult
}

public enum FestivalFlagFollowServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalFlagFollowService {
    UnimplementedFestivalFlagFollowService()
  }
}

public extension DependencyValues {
  var festivalFlagFollowService: any FestivalFlagFollowService {
    get { self[FestivalFlagFollowServiceDependency.self] }
    set { self[FestivalFlagFollowServiceDependency.self] = newValue }
  }
}

private struct UnimplementedFestivalFlagFollowService: FestivalFlagFollowService {
  func setFollowing(_: Bool, flagID _: String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    reportIssue("festivalFlagFollowService가 주입되지 않았습니다.")
    throw .unavailable
  }
}
