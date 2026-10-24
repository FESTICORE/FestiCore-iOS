//
//  FestiCoreFestivalLiveActivity.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ActivityKit
import Foundation

public struct FestiCoreFestivalPushToken: Equatable, Sendable {
  public let festivalID: String
  public let activityID: String
  public let value: String

  public init(festivalID: String, activityID: String, value: String) {
    self.festivalID = festivalID
    self.activityID = activityID
    self.value = value
  }
}

public enum FestiCoreFestivalLiveActivity {
  public enum Error: Swift.Error {
    case disabled
  }

  @discardableResult
  public static func start(
    festivalID: String,
    festivalName: String,
    startDate: Date,
    remoteUpdates: Bool = false
  ) throws -> String {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw Error.disabled
    }

    let activity = try Activity.request(
      attributes: FestiCoreFestivalActivityAttributes(
        festivalID: festivalID,
        festivalName: festivalName
      ),
      content: content(phase: .upcoming, startDate: startDate),
      pushType: remoteUpdates ? .token : nil
    )
    return activity.id
  }

  /// 현재 토큰과 이후 교체된 토큰을 전달한다. 관찰이 끝나면 소비 작업을 취소한다.
  public static func pushTokenUpdates(id: String) -> AsyncStream<FestiCoreFestivalPushToken>? {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return nil
    }

    return AsyncStream { continuation in
      let task = Task {
        var lastToken: Data?
        if let token = activity.pushToken {
          lastToken = token
          continuation.yield(pushToken(token, for: activity))
        }
        for await token in activity.pushTokenUpdates {
          guard !Task.isCancelled else { break }
          guard token != lastToken else { continue }
          lastToken = token
          continuation.yield(pushToken(token, for: activity))
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  public static func update(
    id: String,
    phase: FestiCoreFestivalActivityAttributes.ContentState.Phase,
    startDate: Date
  ) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.update(content(phase: phase, startDate: startDate))
  }

  public static func end(id: String) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.end(nil, dismissalPolicy: .immediate)
  }

  private static func content(
    phase: FestiCoreFestivalActivityAttributes.ContentState.Phase,
    startDate: Date
  ) -> ActivityContent<FestiCoreFestivalActivityAttributes.ContentState> {
    ActivityContent(
      state: .init(phase: phase, startDate: startDate),
      staleDate: phase == .upcoming ? startDate : nil
    )
  }

  private static func pushToken(
    _ data: Data,
    for activity: Activity<FestiCoreFestivalActivityAttributes>
  ) -> FestiCoreFestivalPushToken {
    FestiCoreFestivalPushToken(
      festivalID: activity.attributes.festivalID,
      activityID: activity.id,
      value: data.map { String(format: "%02x", $0) }.joined()
    )
  }
}
