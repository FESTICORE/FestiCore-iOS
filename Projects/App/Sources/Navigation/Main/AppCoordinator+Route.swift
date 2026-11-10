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
        await send(.inner(.completeHomeTransition))
      }

    default:
      return .none
    }
  }

  /// 첫 설치 여부에 따라 온보딩이나 홈으로 바꾸고, 홈에 들어가면 세션 만료 구독과 대기 딥링크를 시작한다.
  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .firstInstallStatus(hasCompleted):
      guard case .splash = state else { return .none }
      if hasCompleted {
        return .send(.inner(.completeHomeTransition))
      }
      state = .onboarding(.init())
      return .none

    case .completeHomeTransition:
      if case .home = state {
        return .none
      }
      state = .home(.init())
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
}
