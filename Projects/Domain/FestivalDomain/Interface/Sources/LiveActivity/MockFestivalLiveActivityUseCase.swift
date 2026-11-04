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
  private let startHandler:
    @Sendable (String, String, Date, Date, FestivalLiveActivityPhase) async throws -> String
  private let updateHandler: @Sendable (
    String,
    FestivalLiveActivityPhase,
    Date,
    Date,
    FestivalPackDocument?,
    Set<String>
  ) async -> Void
  private let finishHandler: @Sendable (String, Date) async -> Void
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
    start: @escaping @Sendable (
      _ festivalID: String, _ festivalName: String, _ startDate: Date, _ endDate: Date,
      _ phase: FestivalLiveActivityPhase
    ) async throws -> String = { _, _, _, _, _ in
      reportIssue("festivalLiveActivityUseCase.start 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    update: @escaping @Sendable (
      _ activityID: String,
      _ phase: FestivalLiveActivityPhase,
      _ startDate: Date,
      _ endDate: Date,
      _ pack: FestivalPackDocument?,
      _ savedSetIDs: Set<String>
    ) async -> Void = { _, _, _, _, _, _ in
      reportIssue("festivalLiveActivityUseCase.update 미등록")
    },
    finish: @escaping @Sendable (_ activityID: String, _ startDate: Date) async -> Void = { _, _ in
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

  public func start(
    festivalID: String, festivalName: String, startDate: Date, endDate: Date, phase: FestivalLiveActivityPhase
  ) async throws -> String {
    try await startHandler(festivalID, festivalName, startDate, endDate, phase)
  }

  public func update(
    activityID: String,
    phase: FestivalLiveActivityPhase,
    startDate: Date,
    endDate: Date,
    pack: FestivalPackDocument?,
    savedSetIDs: Set<String>
  ) async {
    await updateHandler(
      activityID,
      phase,
      startDate,
      endDate,
      pack,
      savedSetIDs
    )
  }

  public func finish(activityID: String, startDate: Date) async {
    await finishHandler(activityID, startDate)
  }

  public func end(activityID: String) async {
    await endHandler(activityID)
  }
}
