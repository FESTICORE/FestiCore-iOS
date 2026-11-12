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

  /// 같은 축제 활동을 동시에 두 번 요청하지 않도록 시작을 직렬화한다.
  private static let startLock = NSLock()

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

    startLock.lock()
    defer { startLock.unlock() }

    // push-to-start로 이미 생긴 활동이나 먼저 시작한 활동이 있으면 새로 만들지 않는다.
    if let existing = partitionDuplicates(activities()).kept.first(where: { $0.festivalID == festivalID }) {
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
    endDate: Date? = nil,
    nowStages: [FestiCoreFestivalActivityAttributes.ContentState.NowStage]? = nil,
    nextMine: FestiCoreFestivalActivityAttributes.ContentState.NextMine? = nil,
    isNextMineKnown: Bool? = nil
  ) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.update(content(
      phase: phase,
      startDate: startDate,
      endDate: endDate,
      nowStages: nowStages,
      nextMine: nextMine,
      isNextMineKnown: isNextMineKnown,
      previousState: activity.content.state
    ))
  }

  public static func end(id: String) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    await activity.end(nil, dismissalPolicy: .immediate)
  }

  /// 같은 축제에 활동이 둘 이상이면 하나만 남기고 나머지를 즉시 종료한다. 종료한 ID를 돌려준다.
  @discardableResult
  public static func endDuplicates() async -> [String] {
    let duplicateIDs = Set(partitionDuplicates(activities()).duplicates.map(\.id))
    guard !duplicateIDs.isEmpty else { return [] }
    for activity in Activity<FestiCoreFestivalActivityAttributes>.activities where duplicateIDs.contains(activity.id) {
      await activity.end(
        nil,
        dismissalPolicy: .immediate
      )
    }
    return duplicateIDs.sorted()
  }

  /// 축제마다 남길 활동 하나와 정리할 중복 활동을 나눈다.
  /// active, stale, pending 순으로 남기고 같은 상태면 ID 순서로 정해 입력 순서와 무관하게 같은 결과를 낸다.
  public static func partitionDuplicates(
    _ activities: [FestiCoreFestivalActivitySummary]
  ) -> (kept: [FestiCoreFestivalActivitySummary], duplicates: [FestiCoreFestivalActivitySummary]) {
    let ordered = activities.sorted {
      let lhsRank = stateRank($0.state)
      let rhsRank = stateRank($1.state)
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      return $0.id < $1.id
    }
    var keptFestivalIDs = Set<String>()
    var kept: [FestiCoreFestivalActivitySummary] = []
    var duplicates: [FestiCoreFestivalActivitySummary] = []
    for activity in ordered {
      if keptFestivalIDs.insert(activity.festivalID).inserted {
        kept.append(activity)
      } else {
        duplicates.append(activity)
      }
    }
    return (
      kept: kept,
      duplicates: duplicates
    )
  }

  public static func endFinished(id: String, startDate: Date) async {
    guard let activity = Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id }) else {
      return
    }
    let endDate = activity.content.state.endDate
    await activity.end(
      content(
        phase: .finished,
        startDate: startDate,
        endDate: endDate,
        previousState: activity.content.state
      ),
      dismissalPolicy: finishedDismissalDate(endDate: endDate).map { .after($0) } ?? .default
    )
  }

  /// 종료한 활동을 공연 종료 3시간 뒤에 내린다. 종료 시각을 모르면 nil을 돌려 시스템 기본 정책을 쓴다.
  static func finishedDismissalDate(endDate: Date?) -> Date? {
    return endDate?.addingTimeInterval(3 * 3_600)
  }

  static func content(
    phase: FestiCoreFestivalActivityAttributes.ContentState.Phase,
    startDate: Date,
    endDate: Date? = nil,
    nowStages: [FestiCoreFestivalActivityAttributes.ContentState.NowStage]? = nil,
    nextMine: FestiCoreFestivalActivityAttributes.ContentState.NextMine? = nil,
    isNextMineKnown: Bool? = nil,
    previousState: FestiCoreFestivalActivityAttributes.ContentState? = nil,
    updatedAt: Date = .now
  ) -> ActivityContent<FestiCoreFestivalActivityAttributes.ContentState> {
    // true면 받은 값을 그대로 쓰고, false면 표시 중인 값을 유지한다.
    // nil이면 공연 목록(nowStages)을 새로 받은 갱신일 때만 바꾼다.
    let keepsNextMine = isNextMineKnown.map { !$0 } ?? (nowStages == nil)
    return ActivityContent(
      state: .init(
        phase: phase,
        startDate: startDate,
        endDate: endDate,
        nowStages: nowStages ?? previousState?.nowStages ?? [],
        nextMine: keepsNextMine ? (nextMine ?? previousState?.nextMine) : nextMine,
        isNextMineConfirmed: keepsNextMine ? previousState?.isNextMineConfirmed : isNextMineKnown,
        pinnedFlag: previousState?.pinnedFlag,
        crewSummary: previousState?.crewSummary,
        leaveAt: previousState?.leaveAt
      ),
      staleDate: staleDate(
        for: phase,
        updatedAt: updatedAt
      )
    )
  }

  static func staleDate(
    for phase: FestiCoreFestivalActivityAttributes.ContentState.Phase,
    updatedAt: Date
  ) -> Date? {
    switch phase {
    case .upcoming, .ongoing:
      return updatedAt.addingTimeInterval(3_600)
    case .finished:
      return nil
    }
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

  private static func stateRank(_ state: ActivityState) -> Int {
    switch state {
    case .active:
      return 0
    case .stale:
      return 1
    default:
      return 2
    }
  }

  private static func isCurrent(_ state: ActivityState) -> Bool {
    if state == .active || state == .stale { return true }
    if #available(iOS 26.0, *) { return state == .pending }
    return false
  }
}
