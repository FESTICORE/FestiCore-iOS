//
//  TimetableActionData.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public enum AnalyticsTimetableAction: String, Sendable {
  case setOpen = "set_open"
  case scheduleToggle = "schedule_toggle"
  case mineOnlyToggle = "mine_only_toggle"
  case daySelect = "day_select"
}

public struct TimetableActionData: Equatable, Sendable {
  public let action: AnalyticsTimetableAction
  public let festivalID: String
  /// 공연 단위 조작일 때만 보낸다.
  public let setID: String?

  public init(action: AnalyticsTimetableAction, festivalID: String, setID: String? = nil) {
    self.action = action
    self.festivalID = festivalID
    self.setID = setID
  }
}
