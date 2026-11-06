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
  case signUpSubmit = "sign_up_submit"
  case signUpCompleted = "sign_up_completed"
  // 팩 상세
  case packDirectionsTab = "pack_directions_tab"
  case packChecklistTab = "pack_checklist_tab"
  case packManageTab = "pack_manage_tab"
  case packLinkOpen = "pack_link_open"
  case packRetry = "pack_retry"
  case packChecklistToggle = "pack_checklist_toggle"
  case packChecklistEdit = "pack_checklist_edit"
  case packChecklistEditDone = "pack_checklist_edit_done"
  case packChecklistItemRemove = "pack_checklist_item_remove"
  case packChecklistItemAdd = "pack_checklist_item_add"
  case packUpdate = "pack_update"
  case packAutoDownloadToggle = "pack_auto_download_toggle"
  case packDelete = "pack_delete"
  // 깃발
  case flagSort = "flag_sort"
  // 타임테이블
  case timetableSearch = "timetable_search"
  case timetableNotify = "timetable_notify"
  // 프로필
  case profileNicknameEdit = "profile_nickname_edit"
  case profileNicknameSave = "profile_nickname_save"
  case profileLogout = "profile_logout"
  case profileWithdraw = "profile_withdraw"
}
