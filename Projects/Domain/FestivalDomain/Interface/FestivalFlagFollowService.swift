//
//  FestivalFlagFollowService.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 10/31/26.
//

import Dependencies
import Foundation

/// 팔로우·해제 뒤 서버가 돌려준 깃발 상태.
public struct FestivalFlagFollowResult: Equatable, Sendable {
  public let flagID: String
  public let isFollowing: Bool
  public let followerCount: Int

  public init(flagID: String, isFollowing: Bool, followerCount: Int) {
    self.flagID = flagID
    self.isFollowing = isFollowing
    self.followerCount = followerCount
  }
}

public enum FestivalFlagFollowError: Error, Equatable, Sendable {
  /// 로그아웃 상태이거나 토큰 갱신 후에도 인증되지 않았다.
  case loginRequired
  /// 팔로우할 수 있는 깃발 수(100개)를 넘었다.
  case limitReached
  /// 공개되지 않은 깃발이다.
  case notFound
  /// 응답 형식이 계약과 다르다.
  case invalidResponse
  /// 연결 오류·5xx처럼 결과를 알 수 없다.
  case unavailable
}

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
