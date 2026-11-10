//
//  AppCoordinator+ScopeAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import CoreAssembly
import FeatureAssembly
import FestiCoreUtility
import Foundation

extension AppCoordinator {
  func handleScopeAction(
    state: inout State,
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

    case .home(.delegate(.myProfileRefreshRequested)):
      return .send(.scope(.home(.session(.view(.retryProfile)))))

    case let .home(.delegate(.myProfileUpdated(user))):
      return state.withHome { home in
        // 바꾼 닉네임을 세션의 표시 이름에 바로 반영한다. 같은 계정일 때만 받는다.
        guard let previous = home.authFlow.profile, previous.user.id == user.id else { return .none }
        home.authFlow.profile = AuthProfile(
          user: user,
          currentTermsVersion: previous.currentTermsVersion
        )
        return .none
      }

    default:
      return .none
    }
  }
}
