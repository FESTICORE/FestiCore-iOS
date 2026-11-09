//
//  AppCoordinator+ScopeAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import AuthInterface
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
      return .send(.view(.retryProfile))

    case .home(.delegate(.myLogoutRequested)):
      return myAccountOperation(
        state: &state,
        operation: .signOut
      )

    case .home(.delegate(.myWithdrawRequested)):
      return myAccountOperation(
        state: &state,
        operation: .withdraw
      )

    // MARK: 예약·가입·로그인

    case let .home(.festival(.delegate(.bookmarkRequested(id)))):
      return state.withHome { home in
        guard home.authFlow.accountOperationGeneration == nil else { return .none }
        return requestBookmark(
          id,
          home: &home
        )
      }

    case let .home(.signUp(.delegate(.submitRequested(submission)))):
      return state.withHome { home in
        return submitSignUp(
          submission,
          home: &home
        )
      }

    case let .home(.login(.delegate(.signedIn(result)))):
      return state.withHome { home in
        return receiveSignedIn(
          result,
          home: &home
        )
      }

    case .home(.delegate(.myLoginRequested)),
         .home(.delegate(.myCrewLoginRequested)),
         .home(.delegate(.myFollowLoginRequested)):
      return state.withHome { home in
        guard !home.authFlow.isLoading else { return .none }
        home.authFlow.generation += 1
        home.authFlow.clearPendingBookmark()
        home.authFlow.message = nil
        home.authFlow.loginContextOverride = loginContext(for: action)
        home.authFlow.presentation = .login
        return .none
      }

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
      guard let viewAction = forwardedViewAction(action) else { return .none }
      return handleViewAction(
        state: &state,
        action: viewAction
      )
    }
  }
}

private extension AppCoordinator {
  func requestBookmark(
    _ id: String,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    let generation = home.authFlow.beginRequest()
    home.authFlow.pendingFestivalID = id
    if let userID = home.authFlow.verifiedUserID, home.authFlow.profile?.isEligible == true {
      home.authFlow.pendingShouldBeBooked = !bookedStore.load(for: userID).contains(id)
    } else {
      home.authFlow.pendingShouldBeBooked = !isBooked(
        id,
        in: home.festivalState
      )
    }
    home.authFlow.pendingOwnerID = home.authFlow.verifiedUserID ?? home.authFlow.lastVerifiedUserID
    home.authFlow.resetSignUpRetryState()
    return fetchProfile(generation: generation)
  }

  func submitSignUp(
    _ submission: SignUpSubmission,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    guard home.authFlow.presentation == .onboarding,
          let profile = home.authFlow.profile,
          home.authFlow.signUp.acceptedTerms,
          home.authFlow.signUp.consentedVersion == profile.currentTermsVersion,
          !home.authFlow.termsUpdateExhausted,
          !home.authFlow.isLoading else { return .none }
    guard submission.isNicknameValid else {
      home.authFlow.message = AuthFlow.Message.invalidNickname
      return .none
    }
    home.authFlow.isLoading = true
    home.authFlow.message = nil
    let generation = home.authFlow.generation
    let nickname = submission.nickname
    let pushOptIn = submission.pushOptIn
    return .run { send in
      do {
        let user = try await authUseCase.updateProfile(
          nickname: nickname,
          termsVersion: profile.currentTermsVersion,
          pushOptIn: pushOptIn
        )
        await send(.inner(.profileUpdated(
          generation: generation,
          .success(user)
        )))
      } catch {
        await send(.inner(.profileUpdated(
          generation: generation,
          .failure(authFailure(error))
        )))
      }
    }
  }

  func receiveSignedIn(
    _ result: AuthLoginResult,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    let accepted = isActiveLoginAttempt(home.authFlow)
    guard let sessionID = result.sessionID else {
      guard accepted else { return .none }
      return acceptLogin(
        result,
        home: &home
      )
    }
    guard accepted else {
      // 시트를 닫은 뒤 끝난 로그인은 확정하지 않고 그 임시 세션만 버린다.
      return .run { _ in _ = await authService.discardSession(sessionID) }
    }
    home.authFlow.pendingCommitSessionID = sessionID
    let generation = home.authFlow.generation
    return .run { send in
      let committed = await authService.commitSession(sessionID)
      await send(.inner(.loginCommitted(
        result,
        generation: generation,
        committed: committed
      )))
    }
  }

  /// 화면 동작을 그대로 넘기는 위임. 같은 상태에서 바로 처리하도록 View 동작으로 대응시킨다.
  func forwardedViewAction(_ action: ScopeAction) -> View? {
    switch action {
    case .home(.signUp(.delegate(.closeRequested))),
         .home(.login(.delegate(.closeRequested))),
         .home(.delegate(.dismissAuthFlow)):
      return .dismissFlow
    case .home(.delegate(.retryProfile)):
      return .retryProfile
    case let .home(.delegate(.resolveMigration(shouldRestore))):
      return .resolveMigration(shouldRestore)
    case let .home(.login(.delegate(.signInRequested(provider)))):
      return .startLogin(provider)
    default:
      return nil
    }
  }

  func loginContext(for action: ScopeAction) -> LoginFeature.State.Context? {
    switch action {
    case .home(.delegate(.myCrewLoginRequested)): return .crew
    case .home(.delegate(.myFollowLoginRequested)): return .follow
    default: return nil
    }
  }
}
