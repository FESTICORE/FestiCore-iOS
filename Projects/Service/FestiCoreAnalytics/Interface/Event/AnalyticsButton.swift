//
//  AnalyticsButton.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public enum AnalyticsButton: String, Sendable, CaseIterable {
  // 로그인
  case loginGoogle = "login_google"
  case loginApple = "login_apple"
  // 페스티벌 목록
  case festivalLiveActivity = "festival_live_activity"
  // 깃발
  case flagSort = "flag_sort"
  // 타임테이블
  case timetableSearch = "timetable_search"
  case timetableNotify = "timetable_notify"
  // 프로필
  case profileLogout = "profile_logout"
  case profileWithdraw = "profile_withdraw"
}
