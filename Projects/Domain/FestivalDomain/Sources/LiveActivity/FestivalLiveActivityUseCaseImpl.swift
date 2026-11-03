//
//  FestivalLiveActivityUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

public struct FestivalLiveActivityUseCaseImpl: FestivalLiveActivityUseCaseInterface {
  @Dependency(\.festivalLiveActivityClient) private var client

  public init() {}

  public func activities() async -> [FestivalLiveActivityRecord] {
    await client.activities()
  }

  public func activityChanges() -> AsyncStream<Void> {
    client.changes()
  }

  public func start(
    festivalID: String, festivalName: String, startDate: Date, endDate: Date, phase: FestivalLiveActivityPhase
  ) async throws -> String {
    try await client.start(festivalID, festivalName, startDate, endDate, phase)
  }

  public func update(activityID: String, phase: FestivalLiveActivityPhase, startDate: Date, endDate: Date) async {
    await client.update(activityID, phase, startDate, endDate)
  }

  public func finish(activityID: String, startDate: Date) async {
    await client.finish(activityID, startDate)
  }

  public func end(activityID: String) async {
    await client.end(activityID)
  }
}
