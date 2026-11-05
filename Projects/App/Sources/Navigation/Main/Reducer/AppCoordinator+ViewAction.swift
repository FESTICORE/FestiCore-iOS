//
//  AppCoordinator+ViewAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import API
import ComposableArchitecture
import CoreAssembly
import FeatureAssembly
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreStorageInterface
import Foundation
import OSLog

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
            category: .app)
          await send(.inner(.firstInstallStatus(true)))
        }
      }

    case .foregrounded:
      guard case var .home(home) = state else { return .none }
      let resumeFestival: Effect<Action> = .send(.scope(.home(.scopeAction(.festival(.foregrounded)))))
      guard home.authFlow.presentation != .login,
            !home.authFlow.isLoading else { return resumeFestival }
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      home.authFlow.presentation = nil
      let generation = home.authFlow.generation
      state = .home(home)
      return .merge(
        resumeFestival,
        fetchProfile(generation: generation),
        .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: nil))))))
      )

    case .backgrounded:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.scopeAction(.festival(.backgrounded)))))

    case let .openWidgetRoute(route):
      guard case .home = state else { return .none }
      return .send(.scope(.home(.openWidgetRoute(route))))

    case let .startLogin(provider):
      // 수락한 로그인을 확정하는 동안 새 로그인을 시작하면 두 결과가 서로의 임시 세션을 무효로 만든다.
      guard case var .home(home) = state,
            home.authFlow.presentation == .login,
            home.authFlow.pendingCommitSessionID == nil else { return .none }
      home.authFlow.loginAttemptGeneration = home.authFlow.generation
      home.authFlow.message = nil
      state = .home(home)
      // 닫았던 시트에서 시작한 로그인이 아직 진행 중이면 새로 시작하지 않고 그 결과를 이번 시도로 받는다.
      guard !home.loginState.isSigningIn else { return .none }
      return .send(.scope(.home(.scopeAction(.login(.view(.signIn(provider)))))))

    case .dismissFlow:
      guard case var .home(home) = state else { return .none }
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
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
      state = .home(home)
      // 확정 전이면 임시 세션을 버리고, 이미 확정됐다면 loginCommitted가 그 세션만 되돌린다.
      guard let pendingCommit else { return .none }
      return .run { _ in _ = await authService.discardSession(pendingCommit) }

    case .retryProfile:
      guard case var .home(home) = state,
            !home.authFlow.isLoading else { return .none }
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      let generation = home.authFlow.generation
      state = .home(home)
      return .merge(
        fetchProfile(generation: generation),
        .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: nil))))))
      )

    case let .resolveMigration(accepted):
      guard case var .home(home) = state,
            home.authFlow.presentation == .migration,
            let userID = home.authFlow.verifiedUserID else { return .none }
      festivalLibraryUseCase.resolveLegacyBookmarkMigration(
        accepted: accepted,
        userID: userID
      )
      home.authFlow.presentation = nil
      let pending = home.authFlow.pendingFestivalID
      let shouldBeBooked = home.authFlow.pendingShouldBeBooked
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
      state = .home(home)
      if let pending {
        return .send(.scope(.home(.completePendingBookmark(
          id: pending,
          userID: userID,
          shouldBeBooked: shouldBeBooked))))
      }
      return .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: userID))))))

    }
  }
}
