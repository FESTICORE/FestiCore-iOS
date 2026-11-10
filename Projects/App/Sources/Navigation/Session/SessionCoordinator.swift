//
//  SessionCoordinator.swift
//  FestiCore
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreAuthInterface
import FestivalDomainInterface
import Foundation

/// 세션 복원·만료와 프로필 조회·재조회, 약관 재동의를 맡는다. 요청 세대(`generation`)로 늦게 온 응답을 버린다.
@Reducer
struct SessionCoordinator {
  @Dependency(\.authUseCase) var authUseCase
  @Dependency(\.authService) var authService
  @Dependency(\.festivalBookedStore) var bookedStore

  enum Action {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(Delegate)
  }

  @CasePathable
  enum View {
    case foregrounded
    case retryProfile
  }

  @CasePathable
  enum AsyncAction {
    case sessionExpired
    case fetchProfile(generation: Int)
  }

  @CasePathable
  enum InnerAction {
    case sessionRestored(
      generation: Int,
      userID: String?,
      isLoggedIn: Bool
    )
    case profileLoaded(
      generation: Int,
      Result<AuthProfile, AuthDomainError>
    )
    case profileUpdated(
      generation: Int,
      Result<AuthUser, AuthDomainError>
    )
  }

  @CasePathable
  enum Delegate {
    /// 이전 계정의 화면 데이터를 바로 비우고 축제 화면에 알린다.
    case accountDataCleared
    /// 축제 화면에 계정이 바뀌었다고만 알린다.
    case accountChanged
    case bookmarksReloadRequested(userID: String?)
    case pendingBookmarkCompleted(
      id: String,
      userID: String,
      shouldBeBooked: Bool
    )
    /// 세션이 끝나 진행 중이던 로그아웃·탈퇴 요청을 취소한다.
    case accountOperationInterrupted
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      return handleRoute(
        state: &state,
        action: action
      )
    }
  }

  func handleRoute(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case let .view(action):
      return handleViewAction(
        state: &state,
        action: action
      )
    case let .async(action):
      return handleAsyncAction(
        state: &state,
        action: action
      )
    case let .inner(action):
      return handleInnerAction(
        state: &state,
        action: action
      )
    case .delegate:
      return .none
    }
  }

  /// 도메인이 매핑하지 않은 오류는 계정 요청 실패로 본다.
  static func authFailure(_ error: any Error) -> AuthDomainError {
    return error as? AuthDomainError ?? .unavailable
  }
}

extension SessionCoordinator {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .foregrounded:
      guard state.presentation != .login, !state.isLoading else { return .none }
      state.presentation = nil
      return recheckProfile(state: &state)

    case .retryProfile:
      guard !state.isLoading else { return .none }
      state.message = nil
      return recheckProfile(state: &state)
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .sessionExpired:
      guard state.hasSession else { return .none }
      return handleSessionExpired(state: &state)

    case let .fetchProfile(generation):
      return fetchProfile(generation: generation)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .sessionRestored(generation, userID, isLoggedIn):
      guard state.generation == generation else { return .none }
      return handleSessionRestored(
        state: &state,
        userID: userID,
        isLoggedIn: isLoggedIn
      )

    case let .profileLoaded(generation, result):
      guard state.generation == generation else { return .none }
      state.isLoading = false
      return handleProfileLoaded(
        state: &state,
        result: result
      )

    case let .profileUpdated(generation, result):
      guard state.generation == generation, let previous = state.profile else { return .none }
      state.isLoading = false
      return handleProfileUpdated(
        state: &state,
        previous: previous,
        result: result
      )
    }
  }
}

// MARK: - 세션

private extension SessionCoordinator {
  func handleSessionExpired(state: inout State) -> Effect<Action> {
    let interruptedOperation = state.accountOperation
    state.forgetVerifiedAccount()
    state.generation += 1
    state.isLoading = false
    state.endAccountOperation()
    state.loginAttemptGeneration = nil
    // 프로필 401 처리와 같이, 로그인이 필요해 멈춘 예약이 있으면 유지하고 로그인 시트를 띄운다.
    // 요청 계정을 모르면 다른 계정에 적용되지 않도록 버린다.
    state.dropUnownedPendingBookmark()
    if state.pendingFestivalID != nil {
      state.presentation = .login
    } else if state.presentation != .login {
      state.presentation = nil
    }
    state.clearSignUpDraft()
    if interruptedOperation == .withdraw {
      state.message = State.Message.sessionExpiredDuringWithdraw
    }
    return .merge(
      .send(.delegate(.accountDataCleared)),
      .send(.delegate(.accountOperationInterrupted)),
      .run { _ in await AccountDeviceSync().releaseSignedOutDevice() }
    )
  }

  func handleSessionRestored(
    state: inout State,
    userID: String?,
    isLoggedIn: Bool
  ) -> Effect<Action> {
    let shouldClearPreviousAccount = state.hasSession && !isLoggedIn
    let eligibleID = userID.flatMap { bookedStore.offlineEligible($0) ? $0 : nil }
    if let userID { state.dropPendingBookmark(notOwnedBy: userID) }
    // 세션이 끊길 때 요청 계정을 모르는 예약은 sessionExpired와 같이 버린다.
    if shouldClearPreviousAccount { state.dropUnownedPendingBookmark() }
    state.verifiedUserID = eligibleID
    state.lastVerifiedUserID = userID
    state.hasSession = isLoggedIn
    if !isLoggedIn, state.pendingFestivalID != nil {
      state.presentation = .login
    }
    let clear: Effect<Action> = shouldClearPreviousAccount ? .send(.delegate(.accountDataCleared)) : .none
    return .merge(
      clear,
      .run { _ in
        let device = AccountDeviceSync()
        if isLoggedIn {
          await device.linkDeviceForCurrentUser()
        } else {
          await device.releaseSignedOutDevice()
        }
      },
      .send(.delegate(.bookmarksReloadRequested(userID: eligibleID)))
    )
  }
}

// MARK: - 프로필

private extension SessionCoordinator {
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
          .failure(.notAuthenticated)
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
          .failure(Self.authFailure(error))
        )))
      }
    }
  }

  /// 확인한 계정을 비우고 새 세대로 프로필을 다시 읽는다. 예약 목록은 비로그인 기준으로 먼저 다시 읽는다.
  func recheckProfile(state: inout State) -> Effect<Action> {
    let generation = state.beginRequest()
    state.profile = nil
    state.verifiedUserID = nil
    return .merge(
      fetchProfile(generation: generation),
      .send(.delegate(.bookmarksReloadRequested(userID: nil)))
    )
  }

  func handleProfileLoaded(
    state: inout State,
    result: Result<AuthProfile, AuthDomainError>
  ) -> Effect<Action> {
    switch result {
    case let .success(profile):
      bookedStore.setOfflineEligible(
        profile.user.id,
        profile.isEligible
      )
      if state.isAccountChanged(to: profile.user.id) {
        state.clearPendingBookmark()
        state.clearSignUpDraft()
      }
      state.reconcileSignUpDraft(userID: profile.user.id)
      state.dropPendingBookmark(notOwnedBy: profile.user.id)
      state.profile = profile
      state.verifiedUserID = profile.user.id
      state.lastVerifiedUserID = profile.user.id
      state.hasSession = true
      if profile.isEligible { return finishEligible(state: &state) }
      state.presentation = .onboarding
      // 서버 닉네임을 채우고, 약관 버전이 바뀌면 이전 버전에 체크한 필수 항목을 모두 지운다.
      state.signUp.apply(
        profileUserID: profile.user.id,
        serverNickname: profile.user.nickname,
        termsVersion: profile.currentTermsVersion
      )
      state.message = state.hasRetriedTermsUpdate ? State.Message.termsChangedReconsent : nil
      return .send(.delegate(.bookmarksReloadRequested(userID: nil)))

    case .failure(.notAuthenticated):
      let hadSession = state.hasSession
      state.forgetVerifiedAccount()
      // 로그인을 잃으면 다른 계정이 이어받지 않도록 가입 초안과 소유자 없는 대기 예약을 지운다.
      // 처음부터 로그인하지 않은 사용자의 예약은 잃은 계정이 없으므로 유지하고 로그인 시트를 띄운다.
      state.clearSignUpDraft()
      if hadSession { state.dropUnownedPendingBookmark() }
      state.presentation = state.pendingFestivalID == nil ? nil : .login
      // 같은 로그아웃을 `sessionRestored`가 이미 비웠다면 그 뒤 받은 비로그인 라이브 보드를 다시 지우지 않고 예약 목록만 정리한다.
      return .send(.delegate(hadSession ? .accountDataCleared : .accountChanged))

    case .failure(.offline):
      state.profile = nil
      if let userID = state.verifiedUserID,
         bookedStore.offlineEligible(userID),
         state.pendingFestivalID != nil {
        state.presentation = nil
        return completePendingBookmark(
          state.takePendingBookmark(),
          userID: userID
        )
      }
      guard state.pendingFestivalID != nil else {
        state.presentation = nil
        return .none
      }
      state.presentation = .retry
      state.message = State.Message.offlineProfile
      return .none

    case .failure:
      state.profile = nil
      state.verifiedUserID = nil
      state.presentation = state.pendingFestivalID == nil ? nil : .retry
      state.message = State.Message.profileUnavailable
      return .send(.delegate(.bookmarksReloadRequested(userID: nil)))
    }
  }

  func handleProfileUpdated(
    state: inout State,
    previous: AuthProfile,
    result: Result<AuthUser, AuthDomainError>
  ) -> Effect<Action> {
    switch result {
    case let .success(user):
      guard user.id == previous.user.id else {
        // 다른 계정 응답은 신뢰하지 않는다. 계정 ID를 모두 지워 세션 변경 감지가 이전 계정 데이터를 비우게 한다.
        state.clearPendingBookmark()
        state.clearSignUpDraft()
        state.presentation = nil
        state.verifiedUserID = nil
        state.lastVerifiedUserID = nil
        state.profile = nil
        return .none
      }
      let profile = AuthProfile(
        user: user,
        currentTermsVersion: previous.currentTermsVersion
      )
      state.profile = profile
      if profile.isEligible { return finishEligible(state: &state) }
      state.message = State.Message.requiredInfoMissing
      return .none

    case .failure(.termsVersionOutdated):
      state.signUp.clearRequiredTerms()
      guard !state.hasRetriedTermsUpdate else {
        state.termsUpdateExhausted = true
        state.message = State.Message.termsChangedAgain
        return .none
      }
      state.hasRetriedTermsUpdate = true
      state.message = State.Message.termsChanged
      return fetchProfile(generation: state.beginRequest())

    case .failure(.notAuthenticated):
      state.forgetVerifiedAccount()
      state.clearSignUpDraft()
      state.dropUnownedPendingBookmark()
      state.presentation = .login
      return .send(.delegate(.accountDataCleared))

    case .failure(.offline):
      state.message = State.Message.saveOffline
      return .none

    case .failure:
      state.message = State.Message.saveFailed
      return .none
    }
  }

  func finishEligible(state: inout State) -> Effect<Action> {
    guard let profile = state.profile, profile.isEligible else { return .none }
    let userID = profile.user.id
    bookedStore.setOfflineEligible(
      userID,
      true
    )
    state.verifiedUserID = userID
    state.lastVerifiedUserID = userID
    state.resetSignUpRetryState()
    if !bookedStore.legacyBookmarks().isEmpty {
      state.presentation = .migration
      return .none
    }
    state.presentation = nil
    return completePendingBookmark(
      state.takePendingBookmark(),
      userID: userID
    )
  }

  /// 대기 예약이 있으면 그 계정으로 마저 반영하고, 없으면 예약 목록만 다시 읽는다.
  func completePendingBookmark(
    _ pending: State.PendingBookmark?,
    userID: String
  ) -> Effect<Action> {
    guard let pending else { return .send(.delegate(.bookmarksReloadRequested(userID: userID))) }
    return .send(.delegate(.pendingBookmarkCompleted(
      id: pending.id,
      userID: userID,
      shouldBeBooked: pending.shouldBeBooked
    )))
  }
}
