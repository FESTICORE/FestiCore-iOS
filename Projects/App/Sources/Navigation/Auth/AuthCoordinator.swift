//
//  AuthCoordinator.swift
//  FestiCore
//

import AuthDomainInterface
import AuthInterface
import ComposableArchitecture
import FeatureAssembly
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import Foundation
import TCAFlow

/// 홈 위에 뜨는 로그인·가입·이전 확인 시트를 맡는다. 로그인 결과는 요청 세대(`generation`)로 확인해 확정하고, 닫은 시트의 임시 세션은 버린다.
@Reducer
struct AuthCoordinator {
  @Dependency(\.authUseCase) var authUseCase
  @Dependency(\.analyticsUseCase) var analyticsUseCase
  @Dependency(\.festivalBookedStore) var bookedStore

  typealias State = AuthFlowState

  // MARK: - Action

  enum Action: ViewAction {
    case view(View)
    case inner(InnerAction)
    case delegate(Delegate)
    case login(LoginFeature.Action)
    case signUp(SignUpAction)
  }

  // MARK: - View

  @CasePathable
  enum View {
    /// 로그인 시트를 연다. 문맥이 없으면 선택한 탭에 맞는 문구를 쓴다.
    case loginRequested(LoginFeature.State.Context?)
    /// 로그인 시트의 로그인 요청(`LoginDelegate.signInRequested`)도 여기서 시트 상태를 확인한다.
    case startLogin(OAuthProvider)
    case dismissFlow
    case resolveMigration(Bool)
    case retryTapped
  }

  // MARK: - Inner

  @CasePathable
  enum InnerAction {
    case loginCommitted(
      AuthLoginResult,
      generation: Int,
      committed: Bool
    )
    case staleLoginDiscarded
  }

  // MARK: - Delegate

  @CasePathable
  enum Delegate {
    /// 세션 코디네이터에 새 세대의 프로필 조회를 맡긴다.
    case profileFetchRequested(generation: Int)
    /// 가입 제출 결과를 세션 코디네이터의 프로필 갱신으로 넘긴다.
    case signUpSubmitted(
      generation: Int,
      Result<AuthUser, AuthDomainError>
    )
    case retryProfileRequested
    case pendingBookmarkResolved(State.PendingBookmarkResolution)
  }

  // MARK: - SignUp

  @CasePathable
  enum SignUpAction {
    case router(IndexedRouterActionOf<SignUpScreen>)
    case view(SignUpFeature.View)
  }

  var body: some ReducerOf<Self> {
    Scope(
      state: \.login,
      action: \.login
    ) {
      LoginFeature()
    }
    Reduce { state, action in
      return handleRoute(
        state: &state,
        action: action
      )
    }
    .forEachRoute(
      \.signUpFlow.routes,
      action: \.signUp.router
    )
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
    case let .login(action):
      return handleLoginAction(
        state: &state,
        action: action
      )
    case let .signUp(action):
      return handleSignUpAction(
        state: &state,
        action: action
      )
    case .delegate:
      return .none
    }
  }
}

extension AuthCoordinator {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .loginRequested(context):
      guard !state.isLoading else { return .none }
      state.generation += 1
      state.clearPendingBookmark()
      state.message = nil
      state.loginContextOverride = context
      state.presentation = .login
      return .none

    case let .startLogin(provider):
      // 수락한 로그인을 확정하는 동안 새 로그인을 시작하면 두 결과가 서로의 임시 세션을 무효로 만든다.
      guard state.presentation == .login, state.pendingCommitSessionID == nil else { return .none }
      state.loginAttemptGeneration = state.generation
      state.message = nil
      // 닫았던 시트에서 시작한 로그인이 아직 진행 중이면 새로 시작하지 않고 그 결과를 이번 시도로 받는다.
      guard !state.login.isSigningIn else { return .none }
      return .send(.login(.view(.signIn(provider))))

    case .dismissFlow:
      state.clearPendingBookmark()
      state.generation += 1
      if state.accountOperationGeneration == nil {
        state.isLoading = false
      }
      state.loginAttemptGeneration = nil
      state.presentation = nil
      state.signUp.resetForDismissal()
      state.signUpFlow.resetNavigation()
      state.resetSignUpRetryState()
      let pendingCommit = state.pendingCommitSessionID
      state.pendingCommitSessionID = nil
      // 확정 전이면 임시 세션을 버리고, 이미 확정됐다면 loginCommitted가 그 세션만 되돌린다.
      guard let pendingCommit else { return .none }
      return .run { _ in _ = await authUseCase.discardSession(pendingCommit) }

    case let .resolveMigration(accepted):
      guard state.presentation == .migration, let userID = state.verifiedUserID else { return .none }
      bookedStore.resolveLegacyMigration(
        accepted: accepted,
        for: userID
      )
      state.presentation = nil
      return .send(.delegate(.pendingBookmarkResolved(state.resolvePendingBookmark(userID: userID))))

    case .retryTapped:
      return .send(.delegate(.retryProfileRequested))
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loginCommitted(result, generation, committed):
      guard state.generation == generation, isActiveLoginAttempt(state) else {
        // 확정하는 사이 시트가 닫혔다. 닫은 로그인의 세션은 그 식별자일 때만 되돌린다.
        guard committed, let sessionID = result.sessionID else { return .none }
        return .run { send in
          if await authUseCase.signOut(ifSession: sessionID) {
            await send(.inner(.staleLoginDiscarded))
          }
        }
      }
      state.pendingCommitSessionID = nil
      guard committed else {
        // 저장에 실패한 로그인은 시트를 유지해 다시 시도할 수 있게 한다.
        state.loginAttemptGeneration = nil
        state.isLoading = false
        state.message = State.Message.loginSaveFailed
        return .none
      }
      return .merge(
        acceptLogin(
          result,
          state: &state
        ),
        .run { _ in await AccountDeviceSync().linkDeviceForCurrentUser() }
      )

    case .staleLoginDiscarded:
      // 그 사이 포그라운드 복원이 되돌린 세션을 화면에 반영했다면 저장소 상태를 다시 읽는다.
      guard state.hasSession,
            state.loginAttemptGeneration == nil,
            state.accountOperationGeneration == nil else { return .none }
      return fetchProfile(generation: state.beginRequest())
    }
  }

  private func handleLoginAction(
    state: inout State,
    action: LoginFeature.Action
  ) -> Effect<Action> {
    switch action {
    case let .delegate(.signedIn(result)):
      return receiveSignedIn(
        result,
        state: &state
      )
    case let .delegate(.signInRequested(provider)):
      return handleViewAction(
        state: &state,
        action: .startLogin(provider)
      )
    case .delegate(.closeRequested):
      return handleViewAction(
        state: &state,
        action: .dismissFlow
      )
    case .view, .async, .inner:
      return .none
    }
  }

  private func handleSignUpAction(
    state: inout State,
    action: SignUpAction
  ) -> Effect<Action> {
    switch action {
    case .view(.sheetClosed):
      state.signUpFlow.resetNavigation()
      return .send(.signUp(.router(.routeAction(
        id: 0,
        action: .signUp(.view(.sheetClosed))
      ))))

    case let .view(view):
      return .send(.signUp(.router(.routeAction(
        id: 0,
        action: .signUp(.view(view))
      ))))

    case let .router(.routeAction(
      id: _,
      action: .signUp(.delegate(.legalDocumentRequested(
        url,
        title
      )))
    )):
      guard !state.signUpFlow.routes.contains(where: { $0.screen.is(\.legalDocument) }) else { return .none }
      state.signUpFlow.routes.push(.legalDocument(.init(
        url: url,
        title: title
      )))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .signUp(.delegate(.submitRequested(submission)))
    )):
      return submitSignUp(
        submission,
        state: &state
      )

    case .router(.routeAction(
      id: _,
      action: .signUp(.delegate(.closeRequested))
    )):
      return handleViewAction(
        state: &state,
        action: .dismissFlow
      )

    case .router(.routeAction(
      id: _,
      action: .legalDocument(.delegate(.backToRoot))
    )):
      state.signUpFlow.routes.goBack()
      return .none

    case .router:
      return .none
    }
  }
}

// MARK: - 로그인 확정

private extension AuthCoordinator {
  /// 시트가 열려 있고 현재 세대의 로그인 시도일 때만 결과를 받아들인다.
  func isActiveLoginAttempt(_ state: State) -> Bool {
    return state.presentation == .login && state.loginAttemptGeneration == state.generation
  }

  func receiveSignedIn(
    _ result: AuthLoginResult,
    state: inout State
  ) -> Effect<Action> {
    let accepted = isActiveLoginAttempt(state)
    guard let sessionID = result.sessionID else {
      guard accepted else { return .none }
      return acceptLogin(
        result,
        state: &state
      )
    }
    guard accepted else {
      // 시트를 닫은 뒤 끝난 로그인은 확정하지 않고 그 임시 세션만 버린다.
      return .run { _ in _ = await authUseCase.discardSession(sessionID) }
    }
    state.pendingCommitSessionID = sessionID
    let generation = state.generation
    return .run { send in
      let committed = await authUseCase.commitSession(sessionID)
      await send(.inner(.loginCommitted(
        result,
        generation: generation,
        committed: committed
      )))
    }
  }

  /// 세션이 바뀐 같은 액션 안에서 `MainTabCoordinator.body`가 `reconcileAccountDisplayData`로 이전 계정의 화면 데이터를 정리한다.
  func acceptLogin(
    _ result: AuthLoginResult,
    state: inout State
  ) -> Effect<Action> {
    if state.isAccountChanged(to: result.user.id) { state.clearPendingBookmark() }
    state.dropPendingBookmark(notOwnedBy: result.user.id)
    state.verifiedUserID = result.user.id
    state.hasSession = true
    state.profile = nil
    state.presentation = nil
    state.loginAttemptGeneration = nil
    // 로그인이 확정된 직후 사용자 ID를 분석 도구에 연결하고, 신규 계정이면 sign_up을 남긴다.
    analyticsUseCase.identify(
      result.user.id,
      result.user.provider
    )
    if result.newUser, let provider = AnalyticsProvider(rawValue: result.user.provider) {
      analyticsUseCase.track(.signUp(method: provider))
    }
    return fetchProfile(generation: state.beginRequest())
  }

  func fetchProfile(generation: Int) -> Effect<Action> {
    return .send(.delegate(.profileFetchRequested(generation: generation)))
  }
}

// MARK: - 가입·이전

private extension AuthCoordinator {
  func submitSignUp(
    _ submission: SignUpSubmission,
    state: inout State
  ) -> Effect<Action> {
    guard state.presentation == .onboarding,
          let profile = state.profile,
          state.signUp.acceptedTerms,
          state.signUp.consentedVersion == profile.currentTermsVersion,
          !state.termsUpdateExhausted,
          !state.isLoading else { return .none }
    guard submission.isNicknameValid else {
      state.message = State.Message.invalidNickname
      return .none
    }
    state.isLoading = true
    state.message = nil
    let generation = state.generation
    let nickname = submission.nickname
    let pushOptIn = submission.pushOptIn
    return .run { send in
      do {
        let user = try await authUseCase.updateProfile(
          nickname: nickname,
          termsVersion: profile.currentTermsVersion,
          pushOptIn: pushOptIn
        )
        await send(.delegate(.signUpSubmitted(
          generation: generation,
          .success(user)
        )))
      } catch {
        await send(.delegate(.signUpSubmitted(
          generation: generation,
          .failure(SessionCoordinator.authFailure(error))
        )))
      }
    }
  }
}

// MARK: - 가입 시트 경로

extension AuthCoordinator {
  /// 가입 화면을 루트로 두고 약관 상세를 그 위에 쌓는 가입 시트의 push 경로
  @ObservableState
  struct SignUpFlow: Equatable {
    var routes: [Route<SignUpScreen.State>]

    init(signUp: SignUpFeature.State = .init()) {
      routes = [.root(
        .signUp(signUp),
        embedInNavigationView: true
      )]
    }

    var signUp: SignUpFeature.State {
      get {
        guard let root = routes.first, case let .signUp(signUp) = root.screen else {
          preconditionFailure("회원가입 흐름에는 가입 화면이 루트로 있어야 합니다")
        }
        return signUp
      }
      set {
        guard !routes.isEmpty, routes[0].screen.is(\.signUp) else {
          preconditionFailure("회원가입 흐름에는 가입 화면이 루트로 있어야 합니다")
        }
        routes[0].screen = .signUp(newValue)
      }
    }

    mutating func resetNavigation() {
      routes.removeAll { !$0.screen.is(\.signUp) }
    }
  }

  @Reducer
  enum SignUpScreen {
    case signUp(SignUpFeature)
    case legalDocument(WebFeature)
  }
}

extension AuthCoordinator.SignUpScreen.State: Equatable {}
