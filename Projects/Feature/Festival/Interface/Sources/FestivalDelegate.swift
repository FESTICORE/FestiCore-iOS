//
//  FestivalDelegate.swift
//  FestivalInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

@CasePathable
public enum FestivalDelegate: Equatable, Sendable {
  case bookmarkRequested(String)
  case loginRequested
  case crewLoginRequested
  case followLoginRequested
  case flagDirectoryRequested
  case packDirectionsRequested(festivalID: String, title: String)
  /// 라이브 보드 상단 종 버튼. 부모가 알림함을 연다.
  case notificationInboxRequested
  /// 빈 팔로우 깃발 카드에서 깃발 탭으로 이동한다.
  case flagTabRequested
  /// 라이브 보드 상단 기수 버튼. 부모가 기수 보드를 연다.
  case bearerBoardRequested(festivalID: String, flagID: String, userID: String?)
}
