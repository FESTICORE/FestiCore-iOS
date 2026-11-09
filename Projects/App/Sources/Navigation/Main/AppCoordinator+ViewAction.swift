//
//  AppCoordinator+ViewAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import CoreAssembly
import FestiCoreUtility
import Foundation

extension AppCoordinator {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .presentHome:
      guard case .splash = state else { return .none }
      return .run { send in
        // 이전 실행에서 남은 개인 Widget 파일은 세션 확인 전에 지운다.
        await festivalWidgetClient.save(nil)
        do {
          await send(.inner(.firstInstallStatus(try firstInstallOnboardingStore.hasCompleted())))
        } catch {
          FestiCoreLogger.error(
            "첫 설치 기록을 확인할 수 없음: \(error.localizedDescription)",
            category: .app
          )
          await send(.inner(.firstInstallStatus(true)))
        }
      }

    case .foregrounded:
      return state.withHome { home in
        let resumeFestival: Effect<Action> = .send(.scope(.home(.festival(.foregrounded))))
        guard home.authFlow.presentation != .login, !home.authFlow.isLoading else { return resumeFestival }
        home.authFlow.presentation = nil
        return .merge(
          resumeFestival,
          recheckProfile(home: &home)
        )
      }

    case .backgrounded:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.festival(.backgrounded))))

    case .remoteContentChanged:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.festival(.remoteContentChanged))))

    case let .openDeeplink(deeplink):
      guard case .home = state else { return .none }
      return .send(.scope(.home(.openDeeplink(deeplink))))

    case .deeplinkReceived:
      // 홈 전환 전이면 대기 값을 남겨 두고, 홈에 들어갈 때 다시 꺼낸다.
      guard case .home = state, let deeplink = AppDeeplinkBridge.consumePending() else { return .none }
      return .send(.view(.openDeeplink(deeplink)))

    case let .startLogin(provider):
      return state.withHome { home in
        // 수락한 로그인을 확정하는 동안 새 로그인을 시작하면 두 결과가 서로의 임시 세션을 무효로 만든다.
        guard home.authFlow.presentation == .login, home.authFlow.pendingCommitSessionID == nil else { return .none }
        home.authFlow.loginAttemptGeneration = home.authFlow.generation
        home.authFlow.message = nil
        // 닫았던 시트에서 시작한 로그인이 아직 진행 중이면 새로 시작하지 않고 그 결과를 이번 시도로 받는다.
        guard !home.loginState.isSigningIn else { return .none }
        return .send(.scope(.home(.login(.view(.signIn(provider))))))
      }

    case .dismissFlow:
      return state.withHome { home in
        home.authFlow.clearPendingBookmark()
        home.authFlow.generation += 1
        if home.authFlow.accountOperationGeneration == nil {
          home.authFlow.isLoading = false
        }
        home.authFlow.loginAttemptGeneration = nil
        home.authFlow.presentation = nil
        home.authFlow.signUp.resetForDismissal()
        home.authFlow.signUpFlow.resetNavigation()
        home.authFlow.resetSignUpRetryState()
        let pendingCommit = home.authFlow.pendingCommitSessionID
        home.authFlow.pendingCommitSessionID = nil
        // 확정 전이면 임시 세션을 버리고, 이미 확정됐다면 loginCommitted가 그 세션만 되돌린다.
        guard let pendingCommit else { return .none }
        return .run { _ in _ = await authService.discardSession(pendingCommit) }
      }

    case .retryProfile:
      return state.withHome { home in
        guard !home.authFlow.isLoading else { return .none }
        home.authFlow.message = nil
        return recheckProfile(home: &home)
      }

    case let .resolveMigration(accepted):
      return state.withHome { home in
        guard home.authFlow.presentation == .migration, let userID = home.authFlow.verifiedUserID else { return .none }
        bookedStore.resolveLegacyMigration(
          accepted: accepted,
          for: userID
        )
        home.authFlow.presentation = nil
        return completePendingBookmark(
          home.authFlow.takePendingBookmark(),
          userID: userID
        )
      }
    }
  }
}
