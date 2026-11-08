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
  /// 라이브 보드 존 칩. 부모가 존 지도(Figma S06)를 열고 그 존을 고른다.
  case zoneMapRequested(festivalID: String, zoneID: String?)
  /// 라이브 보드 내 크루 카드. 부모가 크루 화면(S07)을 연다.
  case crewRequested(crewID: String)
  /// 빈 크루 카드의 크루 만들기. 부모가 크루 만들기 화면을 연다.
  case crewCreateRequested(festivalID: String)
  /// 팩을 처음 받았다. 부모가 준비 안내(S15 내 일정 → 깃발 → 준비물)를 연다.
  case prepGuideRequested(festivalID: String)
}
