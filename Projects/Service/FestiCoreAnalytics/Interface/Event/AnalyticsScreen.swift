//
//  AnalyticsScreen.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public enum AnalyticsScreen: String, Sendable, CaseIterable {
  case splash
  case login
  case signUp = "sign_up"
  case festivalList = "festival_list"
  case festivalFlag = "festival_flag"
  case liveBoard = "live_board"
  case timetable
  case profile
  case web
}
