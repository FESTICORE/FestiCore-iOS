//
//  AppCoordinator+Effects.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import CoreAssembly
import FestiCoreAnalyticsInterface
import FestiCoreUtility
import Foundation

// MARK: - 홈 상태 접근

extension AppCoordinator.State {
  /// 홈일 때만 홈 상태를 고치고 다시 저장한다. 홈이 아니면 아무것도 하지 않는다.
  mutating func withHome(
    _ body: (inout MainTabCoordinator.State) -> Effect<AppCoordinator.Action>
  ) -> Effect<AppCoordinator.Action> {
    guard case var .home(home) = self else { return .none }
    defer { self = .home(home) }
    return body(&home)
  }
}

// MARK: - 로그인·프로필

extension AppCoordinator {
  /// 세션 코디네이터에 새 세대의 프로필 조회를 맡긴다.
  func fetchProfile(generation: Int) -> Effect<Action> {
    return .send(.scope(.home(.session(.async(.fetchProfile(generation: generation))))))
  }

  /// 시트가 열려 있고 현재 세대의 로그인 시도일 때만 결과를 받아들인다.
  func isActiveLoginAttempt(_ flow: AuthFlow) -> Bool {
    return flow.presentation == .login && flow.loginAttemptGeneration == flow.generation
  }

  func acceptLogin(
    _ result: AuthLoginResult,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    let previousSession = home.authInputs.session
    // 세션이 바뀐 같은 액션 안에서 이전 계정의 화면 데이터를 정리한다.
    defer { home.reconcileAccountDisplayData(previousSession: previousSession) }
    if home.authFlow.isAccountChanged(to: result.user.id) { home.authFlow.clearPendingBookmark() }
    home.authFlow.dropPendingBookmark(notOwnedBy: result.user.id)
    home.authFlow.verifiedUserID = result.user.id
    home.authFlow.hasSession = true
    home.authFlow.profile = nil
    home.authFlow.presentation = nil
    home.authFlow.loginAttemptGeneration = nil
    // 로그인이 확정된 직후 사용자 ID를 분석 도구에 연결하고, 신규 계정이면 sign_up을 남긴다.
    analyticsUseCase.identify(
      result.user.id,
      result.user.provider
    )
    if result.newUser, let provider = AnalyticsProvider(rawValue: result.user.provider) {
      analyticsUseCase.track(.signUp(method: provider))
    }
    return fetchProfile(generation: home.authFlow.beginRequest())
  }
}

// MARK: - 예약

extension AppCoordinator {
  /// 대기 예약이 있으면 그 계정으로 마저 반영하고, 없으면 예약 목록만 다시 읽는다.
  func completePendingBookmark(
    _ pending: AuthFlow.PendingBookmark?,
    userID: String
  ) -> Effect<Action> {
    guard let pending else { return reloadBookmarks(userID: userID) }
    return .send(.scope(.home(.completePendingBookmark(
      id: pending.id,
      userID: userID,
      shouldBeBooked: pending.shouldBeBooked
    ))))
  }

  func reloadBookmarks(userID: String?) -> Effect<Action> {
    return .send(.scope(.home(.festival(.reloadBookmarks(userID: userID)))))
  }

  func isBooked(
    _ id: String,
    in festival: FestivalCoordinator.State
  ) -> Bool {
    let board = festival.routes.last { $0.screen.festivalBoard != nil }?.screen.festivalBoard
    return board?.bookedFestivalIDs.contains(id) ?? false
  }
}
