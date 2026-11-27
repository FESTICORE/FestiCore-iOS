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
  case loginRetry = "login_retry"
  // 페스티벌 목록
  case festivalLiveActivity = "festival_live_activity"
  case festivalSearch = "festival_search"
  case festivalFilter = "festival_filter"
  case festivalRefresh = "festival_refresh"
  case festivalTicket = "festival_ticket"
  case festivalDirections = "festival_directions"
  case festivalPackDownload = "festival_pack_download"
  // 깃발
  case flagSort = "flag_sort"
  case flagFollow = "flag_follow"
  // 타임테이블
  case timetableSearch = "timetable_search"
  case timetableNotify = "timetable_notify"
  case timetableMineOnly = "timetable_mine_only"
  case timetableDaySelect = "timetable_day_select"
  case crewCreate = "crew_create"
  case crewJoin = "crew_join"
  case crewStateShare = "crew_state_share"
  case crewGather = "crew_gather"
  case notificationOpen = "notification_open"
  case prepGuideNext = "prep_guide_next"
  case prepGuideSkip = "prep_guide_skip"
  // 프로필
  case profileLogout = "profile_logout"
  case profileWithdraw = "profile_withdraw"
}
