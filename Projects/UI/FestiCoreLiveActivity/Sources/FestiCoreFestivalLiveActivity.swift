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

public struct FestiCoreFestivalActivitySummary: Equatable, Sendable {
  public let id: String
  public let festivalID: String
  public let state: ActivityState
  public let phase: FestiCoreFestivalActivityAttributes.ContentState.Phase
  public let startDate: Date
  public let endDate: Date?

  public init(
    id: String,
    festivalID: String,
    state: ActivityState,
    phase: FestiCoreFestivalActivityAttributes.ContentState.Phase,
    startDate: Date,
    endDate: Date?
  ) {
    self.id = id
    self.festivalID = festivalID
    self.state = state
    self.phase = phase
    self.startDate = startDate
    self.endDate = endDate
  }
}

public enum FestiCoreFestivalLiveActivity {
  public enum Error: Swift.Error {
    case disabled
  }

  public static func activities() -> [FestiCoreFestivalActivitySummary] {
    Activity<FestiCoreFestivalActivityAttributes>.activities.compactMap { activity in
      guard isCurrent(activity.activityState) else {
        return nil
      }
      return FestiCoreFestivalActivitySummary(
        id: activity.id,
        festivalID: activity.attributes.festivalID,
        state: activity.activityState,
        phase: activity.content.state.phase,
        startDate: activity.content.state.startDate,
        endDate: activity.content.state.endDate
      )
    }
  }

  /// 새로운 Activity와 기존 Activity의 상태 변경을 전달한다.
  public static func activityChanges() -> AsyncStream<Void> {
    AsyncStream { continuation in
      let task = Task {
        await withTaskGroup(of: Void.self) { group in
          var observedIDs = Set<String>()

          func observe(_ activity: Activity<FestiCoreFestivalActivityAttributes>) {
            guard observedIDs.insert(activity.id).inserted else { return }
            group.addTask {
              for await _ in activity.activityStateUpdates {
                guard !Task.isCancelled else { break }
                continuation.yield()
              }
            }
          }

          for activity in Activity<FestiCoreFestivalActivityAttributes>.activities {
            observe(activity)
          }
          for await activity in Activity<FestiCoreFestivalActivityAttributes>.activityUpdates {
            guard !Task.isCancelled else { break }
            observe(activity)
            continuation.yield()
          }
          group.cancelAll()
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// 서버가 앱을 실행하지 않고 Activity를 시작할 때 사용할 토큰과 이후 교체된 토큰을 전달한다.
  /// 서버 등록 작업이 취소되면 스트림 소비 작업도 취소한다.
  public static var pushToStartToken: String? {
    Activity<FestiCoreFestivalActivityAttributes>.pushToStartToken?
      .map { String(format: "%02x", $0) }.joined()
  }

  public static func pushToStartTokenUpdates() -> AsyncStream<String> {
    AsyncStream { continuation in
      let task = Task {
        var lastToken: Data?
        if let token = Activity<FestiCoreFestivalActivityAttributes>.pushToStartToken {
          lastToken = token
          continuation.yield(token.map { String(format: "%02x", $0) }.joined())
        }
        for await token in Activity<FestiCoreFestivalActivityAttributes>.pushToStartTokenUpdates {
          guard !Task.isCancelled else { break }
          guard token != lastToken else { continue }
          lastToken = token
          continuation.yield(token.map { String(format: "%02x", $0) }.joined())
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  @discardableResult
  public static func start(
    festivalID: String,
    festivalName: String,
    startDate: Date,
    phase: FestiCoreFestivalActivityAttributes.ContentState.Phase = .upcoming,
    endDate: Date? = nil,
    remoteUpdates: Bool = false
  ) throws -> String {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw Error.disabled
    }

    if let existing = activities().first(where: { $0.festivalID == festivalID }) {
      return existing.id
    }

    let activity = try Activity.request(
      attributes: FestiCoreFestivalActivityAttributes(
        festivalID: festivalID,
        festivalName: festivalName
      ),
      content: content(phase: phase, startDate: startDate, endDate: endDate),
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
    startDate: Date,
    endDate: Date? = nil
  ) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.update(content(phase: phase, startDate: startDate, endDate: endDate))
  }

  public static func end(id: String) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.end(nil, dismissalPolicy: .immediate)
  }

  public static func endFinished(id: String, startDate: Date) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.end(content(phase: .finished, startDate: startDate), dismissalPolicy: .default)
  }

  private static func content(
    phase: FestiCoreFestivalActivityAttributes.ContentState.Phase,
    startDate: Date,
    endDate: Date? = nil
  ) -> ActivityContent<FestiCoreFestivalActivityAttributes.ContentState> {
    let staleDate: Date? = switch phase {
    case .upcoming: startDate
    case .ongoing: endDate
    case .finished: nil
    }
    return ActivityContent(
      state: .init(phase: phase, startDate: startDate, endDate: endDate),
      staleDate: staleDate
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

  private static func isCurrent(_ state: ActivityState) -> Bool {
    if state == .active || state == .stale { return true }
    if #available(iOS 26.0, *) { return state == .pending }
    return false
  }
}
