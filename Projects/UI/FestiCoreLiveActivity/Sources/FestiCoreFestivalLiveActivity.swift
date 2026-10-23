//
//  FestiCoreFestivalLiveActivity.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ActivityKit
import Foundation

public enum FestiCoreFestivalLiveActivity {
  public enum Error: Swift.Error {
    case disabled
  }

  @discardableResult
  public static func start(
    festivalID: String,
    festivalName: String,
    startDate: Date
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
      pushType: nil
    )
    return activity.id
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
}
