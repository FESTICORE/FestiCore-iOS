//
//  AppCoordinator+SessionAction.swift
//  FestiCore
//

import ComposableArchitecture

extension AppCoordinator {
  func fetchProfile(generation: Int) -> Effect<Action> {
    return .run { send in
      let isLoggedIn = await authService.isLoggedIn
      let userID = await authService.currentUserID
      await send(.inner(.sessionRestored(
        generation: generation,
        userID: userID,
        isLoggedIn: isLoggedIn
      )))
      guard isLoggedIn else {
        await send(.inner(.profileLoaded(
          generation: generation,
          .failure(.unauthenticated)
        )))
        return
      }
      do {
        let profile = try await authUseCase.fetchProfile()
        await send(.inner(.profileLoaded(
          generation: generation,
          .success(profile)
        )))
      } catch {
        await send(.inner(.profileLoaded(
          generation: generation,
          .failure(ProfileFailure(error))
        )))
      }
    }
  }

  func handleFirstInstallStatus(
    state: inout State,
    hasCompleted: Bool
  ) -> Effect<Action> {
    guard case .splash = state else { return .none }
    if hasCompleted { return .send(.inner(.completeHomeTransition)) }
    state = .onboarding(.init())
    return .none
  }

  func handleCompleteHomeTransition(state: inout State) -> Effect<Action> {
    switch state {
    case .splash, .onboarding: break
    case .home: return .none
    }
    state = .home(.init())
    return .merge(
      .send(.view(.foregrounded)),
      .run { send in
        for await _ in authSessionExpiryClient.events() {
          await send(.inner(.sessionExpired))
        }
      }
      .cancellable(
        id: CancelID.sessionExpiry,
        cancelInFlight: true
      )
    )
  }

  func handleSessionExpired(state: inout State) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.hasSession else { return .none }
    let interruptedOperation = home.authFlow.accountOperation
    home.authFlow.hasSession = false
    home.authFlow.profile = nil
    home.authFlow.verifiedUserID = nil
    home.authFlow.lastVerifiedUserID = nil
    home.authFlow.generation += 1
    home.authFlow.isLoading = false
    home.authFlow.accountOperationGeneration = nil
    home.authFlow.accountOperation = nil
    home.authFlow.loginAttemptGeneration = nil
    home.authFlow.dropUnownedPendingBookmark()
    if home.authFlow.pendingFestivalID != nil {
      home.authFlow.presentation = .login
    } else if home.authFlow.presentation != .login {
      home.authFlow.presentation = nil
    }
    home.authFlow.clearSignUpDraft()
    if interruptedOperation == .withdraw {
      home.authFlow.message = "로그인이 만료되어 회원 탈퇴 결과를 확인할 수 없어요. 다시 로그인해 계정 상태를 확인해 주세요."
    }
    let clear = clearAccountData(&home)
    state = .home(home)
    return .merge(
      clear,
      .cancel(id: CancelID.accountOperation),
      .run { _ in
        try? await deviceRegistrationService.recoverBoundDevice()
        await endLocalLiveActivities()
      }
    )
  }

  func handleSessionRestored(
    state: inout State,
    generation: Int,
    userID: String?,
    isLoggedIn: Bool
  ) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.generation == generation else { return .none }
    let shouldClearPreviousAccount = home.authFlow.hasSession && !isLoggedIn
    let eligibleID = userID.flatMap {
      festivalLibraryUseCase.isOfflineBookingEligible(userID: $0) ? $0 : nil
    }
    if let ownerID = home.authFlow.pendingOwnerID,
       let userID,
       ownerID != userID {
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
    }
    if shouldClearPreviousAccount { home.authFlow.dropUnownedPendingBookmark() }
    home.authFlow.verifiedUserID = eligibleID
    home.authFlow.lastVerifiedUserID = userID
    home.authFlow.hasSession = isLoggedIn
    if !isLoggedIn, home.authFlow.pendingFestivalID != nil {
      home.authFlow.presentation = .login
    }
    let clear: Effect<Action> = shouldClearPreviousAccount ? clearAccountData(&home) : .none
    state = .home(home)
    return .merge(
      clear,
      .run { _ in
        if isLoggedIn {
          await linkDeviceForCurrentUser()
        } else {
          try? await deviceRegistrationService.recoverBoundDevice()
          await endLocalLiveActivities()
        }
      },
      .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: eligibleID))))))
    )
  }
}
