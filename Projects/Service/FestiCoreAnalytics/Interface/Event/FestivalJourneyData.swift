//
//  FestivalJourneyData.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/26/26.
//

import Foundation

/// Product actions that explain the festival discovery and planning journey.
public enum AnalyticsFestivalAction: String, Equatable, Sendable {
  case selected = "festival_selected"
  case searchSubmitted = "search_submitted"
  case bookmarked = "festival_bookmarked"
  case unbookmarked = "festival_unbookmarked"
  case ticketOpened = "ticket_opened"
  case liveBoardOpened = "live_board_opened"
  case directionsOpened = "directions_opened"
  case prepGuideOpened = "prep_guide_opened"
  case loginCompleted = "login_completed"
}

public enum AnalyticsCrewAction: String, Equatable, Sendable {
  case created
  case joined
  case left
  case statusChanged = "status_changed"
  case gatherCreated = "gather_created"
  case gatherResponded = "gather_responded"
}

public enum AnalyticsActionResult: String, Equatable, Sendable {
  case success
  case failure
}

public enum AnalyticsLiveActivityAction: String, Equatable, Sendable {
  case started
  case stopped
}

public struct AnalyticsJourneyEvent: Equatable, Sendable {
  public let action: AnalyticsFestivalAction

  public init(action: AnalyticsFestivalAction) {
    self.action = action
  }
}

public struct AnalyticsCrewEvent: Equatable, Sendable {
  public let action: AnalyticsCrewAction
  public let result: AnalyticsActionResult

  public init(
    action: AnalyticsCrewAction,
    result: AnalyticsActionResult = .success
  ) {
    self.action = action
    self.result = result
  }
}

public struct AnalyticsLiveActivityEvent: Equatable, Sendable {
  public let action: AnalyticsLiveActivityAction
  public let result: AnalyticsActionResult

  public init(
    action: AnalyticsLiveActivityAction,
    result: AnalyticsActionResult = .success
  ) {
    self.action = action
    self.result = result
  }
}
