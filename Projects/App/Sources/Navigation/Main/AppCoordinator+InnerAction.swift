//
//  AppCoordinator+InnerAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import Foundation

extension AppCoordinator {
  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .firstInstallStatus(hasCompleted):
      guard case .splash = state else { return .none }
      if hasCompleted { return .send(.inner(.completeHomeTransition)) }
      state = .onboarding(.init())
      return .none

    case .completeHomeTransition:
      if case .home = state { return .none }
      state = .home(.init())
      return .merge(
        .send(.view(.foregrounded)),
        .send(.view(.deeplinkReceived)),
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

    case .sessionExpired:
      return state.withHome { home in
        guard home.authFlow.hasSession else { return .none }
        return handleSessionExpired(home: &home)
      }

    case let .sessionRestored(generation, userID, isLoggedIn):
      return state.withHome { home in
        guard home.authFlow.generation == generation else { return .none }
        return handleSessionRestored(
          home: &home,
          userID: userID,
          isLoggedIn: isLoggedIn
        )
      }

    case let .profileLoaded(generation, result):
      return state.withHome { home in
        guard home.authFlow.generation == generation else { return .none }
        home.authFlow.isLoading = false
        return handleProfileLoaded(
          home: &home,
          result: result
        )
      }

    case let .profileUpdated(generation, result):
      return state.withHome { home in
        guard home.authFlow.generation == generation, let previous = home.authFlow.profile else { return .none }
        home.authFlow.isLoading = false
        return handleProfileUpdated(
          home: &home,
          previous: previous,
          result: result
        )
      }

    case let .loginCommitted(result, generation, committed):
      return state.withHome { home in
        guard home.authFlow.generation == generation, isActiveLoginAttempt(home.authFlow) else {
          // 확정하는 사이 시트가 닫혔다. 닫은 로그인의 세션은 그 식별자일 때만 되돌린다.
          guard committed, let sessionID = result.sessionID else { return .none }
          return .run { send in
            if await authService.signOut(ifSession: sessionID) {
              await send(.inner(.staleLoginDiscarded))
            }
          }
        }
        home.authFlow.pendingCommitSessionID = nil
        guard committed else {
          // 저장에 실패한 로그인은 시트를 유지해 다시 시도할 수 있게 한다.
          home.authFlow.loginAttemptGeneration = nil
          home.authFlow.isLoading = false
          home.authFlow.message = AuthFlow.Message.loginSaveFailed
          return .none
        }
        return .merge(
          acceptLogin(
            result,
            home: &home
          ),
          .run { _ in await linkDeviceForCurrentUser() }
        )
      }

    case .staleLoginDiscarded:
      return state.withHome { home in
        // 그 사이 포그라운드 복원이 되돌린 세션을 화면에 반영했다면 저장소 상태를 다시 읽는다.
        guard home.authFlow.hasSession,
              home.authFlow.loginAttemptGeneration == nil,
              home.authFlow.accountOperationGeneration == nil else { return .none }
        return fetchProfile(generation: home.authFlow.beginRequest())
      }

    case let .myAccountFinished(generation, operation, result):
      return state.withHome { home in
        guard home.authFlow.accountOperationGeneration == generation else { return .none }
        home.authFlow.endAccountOperation()
        home.authFlow.isLoading = false
        return handleMyAccountFinished(
          home: &home,
          generation: generation,
          operation: operation,
          result: result
        )
      }
    }
  }
}

// MARK: - 세션

private extension AppCoordinator {
  func handleSessionExpired(home: inout MainTabCoordinator.State) -> Effect<Action> {
    let interruptedOperation = home.authFlow.accountOperation
    home.authFlow.forgetVerifiedAccount()
    home.authFlow.generation += 1
    home.authFlow.isLoading = false
    home.authFlow.endAccountOperation()
    home.authFlow.loginAttemptGeneration = nil
    // 프로필 401 처리와 같이, 로그인이 필요해 멈춘 예약이 있으면 유지하고 로그인 시트를 띄운다.
    // 요청 계정을 모르면 다른 계정에 적용되지 않도록 버린다.
    home.authFlow.dropUnownedPendingBookmark()
    if home.authFlow.pendingFestivalID != nil {
      home.authFlow.presentation = .login
    } else if home.authFlow.presentation != .login {
      home.authFlow.presentation = nil
    }
    home.authFlow.clearSignUpDraft()
    if interruptedOperation == .withdraw {
      home.authFlow.message = AuthFlow.Message.sessionExpiredDuringWithdraw
    }
    return .merge(
      clearAccountData(&home),
      .cancel(id: CancelID.accountOperation),
      .run { _ in
        try? await deviceRegistrationService.recoverBoundDevice()
        await endLocalLiveActivities()
      }
    )
  }

  func handleSessionRestored(
    home: inout MainTabCoordinator.State,
    userID: String?,
    isLoggedIn: Bool
  ) -> Effect<Action> {
    let shouldClearPreviousAccount = home.authFlow.hasSession && !isLoggedIn
    let eligibleID = userID.flatMap { bookedStore.offlineEligible($0) ? $0 : nil }
    if let userID { home.authFlow.dropPendingBookmark(notOwnedBy: userID) }
    // 세션이 끊길 때 요청 계정을 모르는 예약은 sessionExpired와 같이 버린다.
    if shouldClearPreviousAccount { home.authFlow.dropUnownedPendingBookmark() }
    home.authFlow.verifiedUserID = eligibleID
    home.authFlow.lastVerifiedUserID = userID
    home.authFlow.hasSession = isLoggedIn
    if !isLoggedIn, home.authFlow.pendingFestivalID != nil {
      home.authFlow.presentation = .login
    }
    let clear: Effect<Action> = shouldClearPreviousAccount ? clearAccountData(&home) : .none
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
      reloadBookmarks(userID: eligibleID)
    )
  }
}

// MARK: - 프로필

private extension AppCoordinator {
  func handleProfileLoaded(
    home: inout MainTabCoordinator.State,
    result: Result<AuthProfile, ProfileFailure>
  ) -> Effect<Action> {
    switch result {
    case let .success(profile):
      bookedStore.setOfflineEligible(
        profile.user.id,
        profile.isEligible
      )
      if home.authFlow.isAccountChanged(to: profile.user.id) {
        home.authFlow.clearPendingBookmark()
        home.authFlow.clearSignUpDraft()
      }
      home.authFlow.reconcileSignUpDraft(userID: profile.user.id)
      home.authFlow.dropPendingBookmark(notOwnedBy: profile.user.id)
      home.authFlow.profile = profile
      home.authFlow.verifiedUserID = profile.user.id
      home.authFlow.lastVerifiedUserID = profile.user.id
      home.authFlow.hasSession = true
      if profile.isEligible { return finishEligible(home: &home) }
      home.authFlow.presentation = .onboarding
      // 서버 닉네임을 채우고, 약관 버전이 바뀌면 이전 버전에 체크한 필수 항목을 모두 지운다.
      home.authFlow.signUp.apply(
        profileUserID: profile.user.id,
        serverNickname: profile.user.nickname,
        termsVersion: profile.currentTermsVersion
      )
      home.authFlow.message = home.authFlow.hasRetriedTermsUpdate ? AuthFlow.Message.termsChangedReconsent : nil
      return reloadBookmarks(userID: nil)

    case .failure(.unauthenticated):
      let hadSession = home.authFlow.hasSession
      home.authFlow.forgetVerifiedAccount()
      // 로그인을 잃으면 다른 계정이 이어받지 않도록 가입 초안과 소유자 없는 대기 예약을 지운다.
      // 처음부터 로그인하지 않은 사용자의 예약은 잃은 계정이 없으므로 유지하고 로그인 시트를 띄운다.
      home.authFlow.clearSignUpDraft()
      if hadSession { home.authFlow.dropUnownedPendingBookmark() }
      home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .login
      // 같은 로그아웃을 `sessionRestored`가 이미 비웠다면 그 뒤 받은 비로그인 라이브 보드를 다시 지우지 않고 예약 목록만 정리한다.
      return hadSession ? clearAccountData(&home) : notifyAccountChanged()

    case .failure(.offline):
      home.authFlow.profile = nil
      if let userID = home.authFlow.verifiedUserID,
         bookedStore.offlineEligible(userID),
         home.authFlow.pendingFestivalID != nil {
        home.authFlow.presentation = nil
        return completePendingBookmark(
          home.authFlow.takePendingBookmark(),
          userID: userID
        )
      }
      guard home.authFlow.pendingFestivalID != nil else {
        home.authFlow.presentation = nil
        return .none
      }
      home.authFlow.presentation = .retry
      home.authFlow.message = AuthFlow.Message.offlineProfile
      return .none

    case .failure:
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .retry
      home.authFlow.message = AuthFlow.Message.profileUnavailable
      return reloadBookmarks(userID: nil)
    }
  }

  func handleProfileUpdated(
    home: inout MainTabCoordinator.State,
    previous: AuthProfile,
    result: Result<AuthUser, ProfileFailure>
  ) -> Effect<Action> {
    switch result {
    case let .success(user):
      guard user.id == previous.user.id else {
        // 다른 계정 응답은 신뢰하지 않는다. 계정 ID를 모두 지워 세션 변경 감지가 이전 계정 데이터를 비우게 한다.
        home.authFlow.clearPendingBookmark()
        home.authFlow.clearSignUpDraft()
        home.authFlow.presentation = nil
        home.authFlow.verifiedUserID = nil
        home.authFlow.lastVerifiedUserID = nil
        home.authFlow.profile = nil
        return .none
      }
      let profile = AuthProfile(
        user: user,
        currentTermsVersion: previous.currentTermsVersion
      )
      home.authFlow.profile = profile
      if profile.isEligible { return finishEligible(home: &home) }
      home.authFlow.message = AuthFlow.Message.requiredInfoMissing
      return .none

    case .failure(.termsOutdated):
      home.authFlow.signUp.clearRequiredTerms()
      guard !home.authFlow.hasRetriedTermsUpdate else {
        home.authFlow.termsUpdateExhausted = true
        home.authFlow.message = AuthFlow.Message.termsChangedAgain
        return .none
      }
      home.authFlow.hasRetriedTermsUpdate = true
      home.authFlow.message = AuthFlow.Message.termsChanged
      return fetchProfile(generation: home.authFlow.beginRequest())

    case .failure(.unauthenticated):
      home.authFlow.forgetVerifiedAccount()
      home.authFlow.clearSignUpDraft()
      home.authFlow.dropUnownedPendingBookmark()
      home.authFlow.presentation = .login
      return clearAccountData(&home)

    case .failure(.offline):
      home.authFlow.message = AuthFlow.Message.saveOffline
      return .none

    case .failure(.unavailable):
      home.authFlow.message = AuthFlow.Message.saveFailed
      return .none
    }
  }
}

// MARK: - 계정 작업

private extension AppCoordinator {
  func handleMyAccountFinished(
    home: inout MainTabCoordinator.State,
    generation: Int,
    operation: MyAccountOperation,
    result: Result<Void, ProfileFailure>
  ) -> Effect<Action> {
    switch result {
    case .success:
      // 계정 분리 — 다음 사용자와 섞이지 않게 분석 식별자와 슈퍼 프로퍼티를 초기화한다.
      analyticsUseCase.reset()
      home.authFlow = clearedAuthFlow(
        after: home.authFlow,
        generation: generation
      )
      return clearAccountData(&home)

    case .failure(.unauthenticated):
      analyticsUseCase.reset()
      var cleared = clearedAuthFlow(
        after: home.authFlow,
        generation: generation
      )
      if operation == .withdraw {
        cleared.message = AuthFlow.Message.sessionExpiredDuringWithdraw
      }
      home.authFlow = cleared
      return clearAccountData(&home)

    case .failure:
      home.authFlow.message = operation == .withdraw ? AuthFlow.Message.withdrawFailed : AuthFlow.Message.signOutFailed
      return .none
    }
  }

  /// 계정 작업이 끝나면 인증 흐름을 비우되 세대는 되돌리지 않는다.
  func clearedAuthFlow(
    after flow: AuthFlow,
    generation: Int
  ) -> AuthFlow {
    var cleared = AuthFlow()
    cleared.generation = max(
      flow.generation,
      generation
    )
    return cleared
  }
}
