//
//  AppCoordinator+Route.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import CoreAssembly
import FestiCoreUtility
import Foundation

// MARK: - 루트 화면 전환

extension AppCoordinator {
  /// 스플래시·온보딩이 끝났다는 알림을 받아 다음 루트 화면으로 넘긴다.
  func handleScopeAction(
    state _: inout State,
    action: ScopeAction
  ) -> Effect<Action> {
    switch action {
    case .splash(.delegate(.presentHome)):
      return .send(.view(.presentHome))

    case .onboarding(.delegate(.completed)):
      return .run { send in
        do {
          try firstInstallOnboardingStore.markCompleted()
        } catch {
          FestiCoreLogger.error(
            "첫 설치 기록을 저장할 수 없음: \(error.localizedDescription)",
            category: .app
          )
        }
        await send(.inner(.sessionChecked(isLoggedIn: await authService.isLoggedIn)))
      }

    default:
      return .none
    }
  }

  /// 첫 설치 여부에 따라 온보딩으로 보내거나 세션을 확인해 홈(로그아웃이면 첫 진입 화면)으로 바꾼다.
  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .firstInstallStatus(hasCompleted):
      guard case .splash = state else { return .none }
      if hasCompleted {
        return .run { send in
          // 세션을 복원하는 동안 스플래시를 유지해 홈이 먼저 보였다가 가려지지 않게 한다.
          await send(.inner(.sessionChecked(isLoggedIn: await authService.isLoggedIn)))
        }
      }
      state = .onboarding(.init())
      return .none

    case let .sessionChecked(isLoggedIn):
      return enterHome(
        state: &state,
        presentsLaunchLogin: !isLoggedIn
      )

    case .completeHomeTransition:
      return enterHome(
        state: &state,
        presentsLaunchLogin: false
      )
    }
  }

  /// 홈으로 바꾸고 세션 만료 구독과 대기 딥링크를 시작한다. 첫 진입 화면은 건너뛰기 상태를 저장하지 않아 실행마다 다시 뜬다.
  func enterHome(
    state: inout State,
    presentsLaunchLogin: Bool
  ) -> Effect<Action> {
    if case .home = state {
      return .none
    }
    var home = MainTabCoordinator.State()
    if presentsLaunchLogin {
      home.authFlow.presentation = .launchLogin
    }
    state = .home(home)
    return .merge(
      .send(.view(.foregrounded)),
      .send(.view(.deeplinkReceived)),
      .run { send in
        for await _ in authSessionExpiryClient.events() {
          await send(.scope(.home(.session(.view(.sessionExpired)))))
        }
      }
      .cancellable(
        id: CancelID.sessionExpiry,
        cancelInFlight: true
      )
    )
  }
}
