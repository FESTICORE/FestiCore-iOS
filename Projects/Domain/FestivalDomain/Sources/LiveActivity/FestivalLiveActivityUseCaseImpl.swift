//
//  FestivalLiveActivityUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

/// 기기 Live Activity 클라이언트에 축제 작업을 전달한다.
public struct FestivalLiveActivityUseCaseImpl: FestivalLiveActivityUseCaseInterface {
  @Dependency(\.festivalLiveActivityClient) private var client

  public init() {}

  /// 현재 실행 중인 축제 Live Activity를 읽는다.
  public func activities() async -> [FestivalLiveActivityRecord] {
    await client.activities()
  }

  /// Live Activity 상태 변경 신호를 구독한다.
  public func activityChanges() -> AsyncStream<Void> {
    client.changes()
  }

  /// 축제 Live Activity를 시작하고 생성된 ID를 돌려준다.
  public func start(
    festivalID: String, festivalName: String, startDate: Date, endDate: Date, phase: FestivalLiveActivityPhase
  ) async throws -> String {
    try await client.start(festivalID, festivalName, startDate, endDate, phase)
  }

  /// 진행 단계와 시간을 기존 활동에 반영한다.
  public func update(activityID: String, phase: FestivalLiveActivityPhase, startDate: Date, endDate: Date) async {
    await client.update(activityID, phase, startDate, endDate)
  }

  /// 끝난 축제를 종료 상태로 표시한다.
  public func finish(activityID: String, startDate: Date) async {
    await client.finish(activityID, startDate)
  }

  /// 지정한 Live Activity를 종료한다.
  public func end(activityID: String) async {
    await client.end(activityID)
  }
}
