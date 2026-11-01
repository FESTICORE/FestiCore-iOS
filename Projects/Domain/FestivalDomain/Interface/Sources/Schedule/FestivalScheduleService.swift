//
//  FestivalScheduleService.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 10/30/26.
//

import Dependencies
import Foundation

/// 서버에 저장된 내 일정. 공개 팩의 공연 ID 목록이다.
public struct FestivalSchedule: Equatable, Sendable {
  public let setIDs: [String]

  public init(setIDs: [String]) {
    self.setIDs = setIDs
  }
}

public enum FestivalScheduleError: Error, Equatable, Sendable {
  /// 토큰 갱신 후에도 인증되지 않았다. 로그인 전 사용자다.
  case unauthorized
  /// 더 최신 일정이 서버에 있다. 서버 값을 함께 돌려준다.
  case stale(FestivalSchedule)
  /// 서버가 요청을 거부했다(없는 공연 ID 등).
  case rejected
  /// 연결 오류·5xx처럼 결과를 알 수 없다.
  case unavailable
}

public protocol FestivalScheduleService: Sendable {
  func fetch(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule
  /// 내 일정 전체를 교체한다. `clientAt`은 축제마다 이전 요청보다 늦어야 한다.
  func replace(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule
}

public enum FestivalScheduleServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalScheduleService {
    EmptyFestivalScheduleService()
  }
}

public extension DependencyValues {
  var festivalScheduleService: any FestivalScheduleService {
    get { self[FestivalScheduleServiceDependency.self] }
    set { self[FestivalScheduleServiceDependency.self] = newValue }
  }
}

private struct EmptyFestivalScheduleService: FestivalScheduleService {
  func fetch(festivalID _: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    .init(setIDs: [])
  }

  func replace(
    festivalID _: String,
    setIDs: [String],
    clientAt _: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    .init(setIDs: setIDs)
  }
}
