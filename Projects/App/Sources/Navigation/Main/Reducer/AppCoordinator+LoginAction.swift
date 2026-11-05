//
//  AppCoordinator+LoginAction.swift
//  FestiCore
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreAuthInterface
import FestiCoreAnalyticsInterface

extension AppCoordinator {
  func handleLoginCommitted(
    state: inout State,
    result: AuthLoginResult,
    generation: Int,
    committed: Bool
  ) -> Effect<Action> {
    guard case var .home(home) = state else { return .none }
    if home.authFlow.generation == generation, isActiveLoginAttempt(home.authFlow) {
      home.authFlow.pendingCommitSessionID = nil
      state = .home(home)
      if committed {
        return .merge(
          acceptLogin(
            result,
            state: &state
          ),
          .run { _ in await linkDeviceForCurrentUser() }
        )
      }
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.isLoading = false
      home.authFlow.message = "로그인 정보를 저장하지 못했어요. 다시 시도해 주세요."
      state = .home(home)
      return .none
    }
    guard committed, let sessionID = result.sessionID else { return .none }
    return .run { send in
      if await authService.signOut(ifSession: sessionID) {
        await send(.inner(.staleLoginDiscarded))
      }
    }
  }

  func handleStaleLoginDiscarded(state: inout State) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.hasSession,
          home.authFlow.loginAttemptGeneration == nil,
          home.authFlow.accountOperationGeneration == nil else { return .none }
    home.authFlow.generation += 1
    home.authFlow.isLoading = true
    let generation = home.authFlow.generation
    state = .home(home)
    return fetchProfile(generation: generation)
  }

  func isActiveLoginAttempt(_ flow: AuthFlow) -> Bool {
    return flow.presentation == .login && flow.loginAttemptGeneration == flow.generation
  }

  func acceptLogin(
    _ result: AuthLoginResult,
    state: inout State
  ) -> Effect<Action> {
    guard case var .home(home) = state else { return .none }
    if let oldID = home.authFlow.verifiedUserID, oldID != result.user.id {
      clearPendingBookmark(&home.authFlow)
    }
    if let oldID = home.authFlow.lastVerifiedUserID, oldID != result.user.id {
      clearPendingBookmark(&home.authFlow)
    }
    if let ownerID = home.authFlow.pendingOwnerID, ownerID != result.user.id {
      clearPendingBookmark(&home.authFlow)
    }
    home.authFlow.verifiedUserID = result.user.id
    home.authFlow.hasSession = true
    home.authFlow.profile = nil
    home.authFlow.presentation = nil
    home.authFlow.loginAttemptGeneration = nil
    analyticsUseCase.identify(
      result.user.id,
      result.user.provider
    )
    if result.newUser, let provider = AnalyticsProvider(rawValue: result.user.provider) {
      analyticsUseCase.track(.signUp(method: provider))
    }
    home.authFlow.generation += 1
    home.authFlow.isLoading = true
    let generation = home.authFlow.generation
    state = .home(home)
    return fetchProfile(generation: generation)
  }
}
