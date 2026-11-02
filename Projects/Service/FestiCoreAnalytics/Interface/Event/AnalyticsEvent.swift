//
//  AnalyticsEvent.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public enum AnalyticsEvent: Equatable, Sendable {
  /// 신규 계정으로 로그인이 확정됐을 때.
  case signUp(method: AnalyticsProvider)
  /// 화면 진입.
  case screenView(screen: AnalyticsScreen, referrer: AnalyticsScreen?)
  /// 버튼 탭 전반.
  case uiAction(action: AnalyticsButton, screen: AnalyticsScreen)
  /// 깃발 팔로우·해제.
  case flagFollow(FlagFollowData)
  /// 타임테이블 조작.
  case timetableAction(TimetableActionData)
  /// 페스티벌 팩 동기화 결과.
  case packSync(PackSyncData)
}
