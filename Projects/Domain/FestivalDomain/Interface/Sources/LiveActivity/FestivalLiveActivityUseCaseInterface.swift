//
//  FestivalLiveActivityUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import Foundation

/// 축제 Live Activity를 켜고 끄고 단계를 맞춘다.
public protocol FestivalLiveActivityUseCaseInterface: Sendable {
  /// 현재 기기에서 실행 중인 축제 Live Activity를 읽는다.
  func activities() async -> [FestivalLiveActivityRecord]
  /// Live Activity 목록이 바뀔 때마다 신호를 보낸다.
  func activityChanges() -> AsyncStream<Void>
  /// 새 Live Activity를 켜고 ID를 돌려준다.
  func start(
    festivalID: String, festivalName: String, startDate: Date, endDate: Date, phase: FestivalLiveActivityPhase
  ) async throws -> String
  /// 진행 단계와 축제 시간을 기존 Live Activity에 반영한다.
  func update(activityID: String, phase: FestivalLiveActivityPhase, startDate: Date, endDate: Date) async
  /// 끝난 축제의 Live Activity를 종료 상태로 닫는다.
  func finish(activityID: String, startDate: Date) async
  /// 지정한 Live Activity를 종료한다.
  func end(activityID: String) async
}

public enum FestivalLiveActivityUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalLiveActivityUseCaseInterface { MockFestivalLiveActivityUseCase() }
  public static var previewValue: any FestivalLiveActivityUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalLiveActivityUseCase: any FestivalLiveActivityUseCaseInterface {
    get { self[FestivalLiveActivityUseCaseDependency.self] }
    set { self[FestivalLiveActivityUseCaseDependency.self] = newValue }
  }
}
