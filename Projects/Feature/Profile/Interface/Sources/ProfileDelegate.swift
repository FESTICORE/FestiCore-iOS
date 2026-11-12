//
//  ProfileDelegate.swift
//  ProfileInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

import AuthDomainInterface

@CasePathable
public enum ProfileDelegate: Equatable, Sendable {
  case bearerRequested
  /// More D 내 깃발 줄. 그 깃발의 프로필 수정(S10)을 연다.
  case bearerProfileRequested(
    festivalID: String,
    flagID: String
  )
  /// More D '기수 보드 열기'. 그 깃발의 기수 보드(S09)를 연다.
  case bearerBoardRequested(
    festivalID: String,
    flagID: String
  )
  case searchRequested
  /// 받은 팩이 없을 때 '페스티벌 둘러보기'. 라이브 탭의 페스티벌 목록(S00)을 연다.
  case festivalListRequested
  case loginRequested
  /// 로그인 카드의 Apple·Google 버튼. 로그인 시트를 열고 그 제공자로 바로 로그인을 시작한다.
  case socialLoginRequested(OAuthProvider)
  case profileRefreshRequested
  case logoutRequested
  case withdrawRequested
  /// 닉네임을 바꿔 세션의 표시 이름을 갱신해야 한다.
  case profileUpdated(AuthUser)
}
