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

  typealias State = AuthFlowState

  enum Action {
    case view(View)
    case inner(InnerAction)
    case delegate(Delegate)
  }

  /// 부모와 다른 코디네이터가 세션에 맡기는 명령
  @CasePathable
  enum View {
    case foregrounded
    case retryProfile
    /// 마이에서 바꾼 프로필을 표시 이름에 바로 반영한다.
    case profileUpdated(AuthUser)
    /// 인증 만료 알림이나 계정 작업 중 인증 상실로 세션을 끝낸다.
    case sessionExpired
    /// 로그인 확정 뒤 열린 세대로 프로필을 읽는다.
    case fetchProfile(generation: Int)
    /// 가입 제출 결과를 그 세대의 프로필 갱신으로 반영한다.
    case signUpSubmitted(
      generation: Int,
      Result<AuthUser, AuthDomainError>
    )
    /// 예약을 대기시키고 새 세대로 프로필을 확인한다. `displayedAsBooked`는 화면에 보이는 예약 여부다.
    case bookmarkRequested(
      id: String,
      displayedAsBooked: Bool
    )
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
  }

  @CasePathable
  enum Delegate {
    /// 이전 계정의 화면 데이터를 바로 비우고 축제 화면에 알린다.
    case accountDataCleared
    /// 축제 화면에 계정이 바뀌었다고만 알린다.
    case accountChanged
    /// 세션 복원·재확인·실패처럼 계정이 정해지지 않았거나 바뀐 뒤 예약 목록만 다시 읽는다.
    /// 확인 전이면 `nil`로 계정 없이 읽으며, 대기 예약은 건드리지 않는다.
    case bookmarksReloadRequested(userID: String?)
    /// 확정된 계정으로 대기 예약을 마저 반영하거나, 대기 예약이 없으면 그 계정의 목록을 다시 읽는다.
    /// 대기 예약을 소비하는 경로라 확정된 `userID`가 반드시 있다.
    case pendingBookmarkResolved(State.PendingBookmarkResolution)
    /// 세션이 끝나 진행 중이던 로그아웃·탈퇴 요청을 취소한다.
    case accountOperationInterrupted
    /// 가입 정보(S14 B)를 마쳐 시트가 닫혔다. 다음은 기수 여부(S14 C)다.
    case signUpCompleted
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
      // 가입 직후 기수 설정(S14 C~E) 중에는 그 스택을 유지한다.
      guard state.presentation?.acceptsLogin != true,
            state.presentation != .bearerSetup,
            !state.isLoading else { return .none }
      state.presentation = nil
      return recheckProfile(state: &state)

    case .retryProfile:
      guard !state.isLoading else { return .none }
      state.message = nil
      return recheckProfile(state: &state)

    case let .profileUpdated(user):
      // 같은 계정의 결과만 받는다.
      guard let previous = state.profile, previous.user.id == user.id else { return .none }
      state.profile = AuthProfile(
        user: user,
        currentTermsVersion: previous.currentTermsVersion
      )
      return .none

    case .sessionExpired:
      guard state.hasSession else { return .none }
      return handleSessionExpired(state: &state)

    case let .fetchProfile(generation):
      return fetchProfile(generation: generation)

    case let .signUpSubmitted(generation, result):
      guard state.generation == generation, let previous = state.profile else { return .none }
      state.isLoading = false
      return handleProfileUpdated(
        state: &state,
        previous: previous,
        result: result
      )

    case let .bookmarkRequested(id, displayedAsBooked):
      return requestBookmark(
        id,
        displayedAsBooked: displayedAsBooked,
        state: &state
      )
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
    } else if state.presentation?.acceptsLogin != true {
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
        return .send(.delegate(.pendingBookmarkResolved(state.resolvePendingBookmark(userID: userID))))
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
      if profile.isEligible {
        let finished = finishEligible(state: &state)
        // 예약 이전 확인처럼 다른 시트가 이어지면 그 시트를 먼저 끝내고 기수 여부는 묻지 않는다.
        guard state.presentation == nil else { return finished }
        // 약관에 처음 동의한 신규 가입만 묻는다. 새 약관에 다시 동의한 기존 계정에는 묻지 않는다.
        guard previous.user.termsAcceptedAt == nil else { return finished }
        return .merge(
          finished,
          .send(.delegate(.signUpCompleted))
        )
      }
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
    return .send(.delegate(.pendingBookmarkResolved(state.resolvePendingBookmark(userID: userID))))
  }
}

// MARK: - 예약 요청

private extension SessionCoordinator {
  /// 예약은 계정의 일이라 새 세대로 프로필을 확인한 뒤 반영한다. 로그아웃·탈퇴 중에는 받지 않는다.
  func requestBookmark(
    _ id: String,
    displayedAsBooked: Bool,
    state: inout State
  ) -> Effect<Action> {
    guard state.accountOperationGeneration == nil else { return .none }
    let generation = state.beginRequest()
    state.pendingFestivalID = id
    if let userID = state.verifiedUserID, state.profile?.isEligible == true {
      state.pendingShouldBeBooked = !bookedStore.load(for: userID).contains(id)
    } else {
      state.pendingShouldBeBooked = !displayedAsBooked
    }
    state.pendingOwnerID = state.verifiedUserID ?? state.lastVerifiedUserID
    state.resetSignUpRetryState()
    return fetchProfile(generation: generation)
  }
}
