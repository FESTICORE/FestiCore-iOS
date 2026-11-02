//
//  AnalyticsScreen.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/2/26.
//

/// 화면 조회 이벤트에 남기는 화면 이름. 원시 값은 Mixpanel·Sentry에 그대로 기록된다.
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
