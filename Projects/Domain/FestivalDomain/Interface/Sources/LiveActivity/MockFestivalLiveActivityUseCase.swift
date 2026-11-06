//
//  MockFestivalLiveActivityUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import Foundation

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalLiveActivityUseCase: FestivalLiveActivityUseCaseInterface {
  private let activitiesHandler: @Sendable () async -> [FestivalLiveActivityRecord]
  private let activityChangesHandler: @Sendable () -> AsyncStream<Void>
  private let startHandler: @Sendable (FestivalLiveActivityStartRequest) async throws -> String
  private let updateHandler: @Sendable (FestivalLiveActivityUpdateRequest) async -> Void
  private let finishHandler: @Sendable (FestivalLiveActivityFinishRequest) async -> Void
  private let endHandler: @Sendable (String) async -> Void

  public init(
    activities: @escaping @Sendable () async -> [FestivalLiveActivityRecord] = {
      reportIssue("festivalLiveActivityUseCase.activities 미등록")
      return []
    },
    activityChanges: @escaping @Sendable () -> AsyncStream<Void> = {
      reportIssue("festivalLiveActivityUseCase.activityChanges 미등록")
      return AsyncStream { $0.finish() }
    },
    start: @escaping @Sendable (FestivalLiveActivityStartRequest) async throws -> String = { _ in
      reportIssue("festivalLiveActivityUseCase.start 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    update: @escaping @Sendable (FestivalLiveActivityUpdateRequest) async -> Void = { _ in
      reportIssue("festivalLiveActivityUseCase.update 미등록")
    },
    finish: @escaping @Sendable (FestivalLiveActivityFinishRequest) async -> Void = { _ in
      reportIssue("festivalLiveActivityUseCase.finish 미등록")
    },
    end: @escaping @Sendable (_ activityID: String) async -> Void = { _ in
      reportIssue("festivalLiveActivityUseCase.end 미등록")
    }
  ) {
    self.activitiesHandler = activities
    self.activityChangesHandler = activityChanges
    self.startHandler = start
    self.updateHandler = update
    self.finishHandler = finish
    self.endHandler = end
  }

  public func activities() async -> [FestivalLiveActivityRecord] {
    await activitiesHandler()
  }

  public func activityChanges() -> AsyncStream<Void> {
    activityChangesHandler()
  }

  public func start(_ request: FestivalLiveActivityStartRequest) async throws -> String {
    return try await startHandler(request)
  }

  public func update(_ request: FestivalLiveActivityUpdateRequest) async {
    await updateHandler(request)
  }

  public func finish(_ request: FestivalLiveActivityFinishRequest) async {
    await finishHandler(request)
  }

  public func end(activityID: String) async {
    await endHandler(activityID)
  }
}
