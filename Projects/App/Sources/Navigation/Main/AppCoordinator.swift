//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import Foundation

@Reducer
struct AppCoordinator {
  @Dependency(\.authUseCase) private var authUseCase
  @Dependency(\.authService) private var authService
  @Dependency(\.festivalBookedStore) private var bookedStore
  @Dependency(\.authSessionExpiryClient) private var authSessionExpiryClient

  private enum CancelID { case sessionExpiry, accountOperation }

  struct AuthFlow: Equatable {
    enum Presentation: Equatable {
      case login
      case onboarding
      case migration
      case retry
    }

    var pendingFestivalID: String?
    var pendingShouldBeBooked = true
    var pendingOwnerID: String?
    var generation = 0
    var accountOperationGeneration: Int?
    var accountOperation: MyAccountOperation?
    var loginAttemptGeneration: Int?
    /// 수락해 확정 중인 로그인 세션. 확정 전에 시트가 닫히면 이 세션을 버린다.
    var pendingCommitSessionID: UUID?
    var verifiedUserID: String?
    var lastVerifiedUserID: String?
    var hasSession = false
    var profile: AuthProfile?
    var presentation: Presentation?
    var nickname = ""
    /// 두 필수 약관(서비스 이용약관·개인정보 수집 이용)이 모두 체크됐을 때만 true다.
    var acceptedTerms = false
    var acceptedServiceTerms = false
    var acceptedPrivacyTerms = false
    var consentedVersion: String?
    var pushOptIn = false
    /// 가입 초안(닉네임·약관·알림)을 만든 계정. 계정이 확인될 때 다르면 초안을 버린다.
    var draftOwnerID: String?
    /// 필수 약관을 체크할 때의 약관 버전. 새 버전 프로필이 오면 체크를 지운다.
    var termsDraftVersion: String?
    /// 사용자가 닉네임을 직접 고쳤는지. 고친 값(빈 값 포함)은 프로필 닉네임으로 덮어쓰지 않는다.
    var nicknameEdited = false
    var isLoading = false
    var hasRetriedTermsUpdate = false
    var termsUpdateExhausted = false
    var message: String?

    var isAllConsented: Bool {
      acceptedServiceTerms && acceptedPrivacyTerms && pushOptIn
    }

    var hasDraft: Bool {
      !nickname.isEmpty || nicknameEdited || acceptedServiceTerms || acceptedPrivacyTerms || acceptedTerms || pushOptIn
    }

    /// 두 필수 약관이 모두 체크됐을 때만 현재 약관 버전에 동의한 것으로 본다.
    mutating func syncRequiredTerms() {
      if acceptedServiceTerms || acceptedPrivacyTerms {
        if termsDraftVersion == nil { termsDraftVersion = profile?.currentTermsVersion }
      } else {
        termsDraftVersion = nil
      }
      acceptedTerms = acceptedServiceTerms && acceptedPrivacyTerms
      consentedVersion = acceptedTerms ? termsDraftVersion : nil
    }

    /// 초안을 처음 바꿀 때 현재 계정을 소유자로 기록한다.
    mutating func claimDraft() {
      if draftOwnerID == nil { draftOwnerID = profile?.user.id }
    }

    /// 요청 계정을 모르는 대기 예약은 다른 계정에 적용되지 않도록 버린다.
    mutating func dropUnownedPendingBookmark() {
      guard pendingOwnerID == nil else { return }
      pendingFestivalID = nil
      pendingShouldBeBooked = false
    }

    /// 약관 버전이 바뀌었을 때처럼 닉네임은 두고 필수 약관 체크만 지운다.
    mutating func clearRequiredTerms() {
      acceptedTerms = false
      acceptedServiceTerms = false
      acceptedPrivacyTerms = false
      termsDraftVersion = nil
      consentedVersion = nil
    }

    mutating func clearDraft() {
      nickname = ""
      nicknameEdited = false
      pushOptIn = false
      draftOwnerID = nil
      clearConsentAndRetryState()
    }

    /// 계정이 확인될 때 다른 계정이 만들었거나 소유자를 모르는 초안은 버린다.
    mutating func reconcileDraft(userID: String) {
      if hasDraft, draftOwnerID != userID {
        clearDraft()
      } else if !hasDraft {
        draftOwnerID = nil
      }
    }

    mutating func clearConsentAndRetryState() {
      acceptedTerms = false
      acceptedServiceTerms = false
      acceptedPrivacyTerms = false
      termsDraftVersion = nil
      consentedVersion = nil
      message = nil
      hasRetriedTermsUpdate = false
      termsUpdateExhausted = false
    }
  }

  @ObservableState
  enum State: Equatable {
    case splash(SplashFeature.State)
    case home(MainTabCoordinator.State)

    init() { self = .splash(SplashFeature.State()) }

    var animationID: String {
      switch self {
      case .splash: "splash"
      case .home: "home"
      }
    }

    /// 라이브 보드에 전달할 세션. 세션 여부와 확인된 사용자 ID가 바뀌면 `FestivalFeature`에 알린다.
    var festivalSession: FestivalSession {
      guard case let .home(home) = self, home.authFlow.hasSession else {
        return FestivalSession(hasSession: false, userID: nil)
      }
      let flow = home.authFlow
      return FestivalSession(
        hasSession: true,
        userID: flow.profile?.user.id ?? flow.verifiedUserID ?? flow.lastVerifiedUserID
      )
    }
  }

  struct FestivalSession: Equatable {
    let hasSession: Bool
    let userID: String?
  }

  enum Action: ViewAction {
    case view(View)
    case inner(InnerAction)
    case scope(ScopeAction)
  }

  @CasePathable
  enum View {
    case presentHome
    case foregrounded
    case startLogin(OAuthProvider)
    case dismissFlow
    case nicknameChanged(String)
    case termsAcceptanceChanged(Bool)
    case serviceTermsChanged(Bool)
    case privacyTermsChanged(Bool)
    case allConsentToggled
    case pushOptInChanged(Bool)
    case submitOnboarding
    case retryProfile
    case resolveMigration(Bool)
  }

  @CasePathable
  enum InnerAction {
    case completeHomeTransition
    case sessionExpired
    case sessionRestored(generation: Int, userID: String?, isLoggedIn: Bool)
    case profileLoaded(generation: Int, Result<AuthProfile, ProfileFailure>)
    case profileUpdated(generation: Int, Result<AuthUser, ProfileFailure>)
    case myAccountFinished(generation: Int, operation: MyAccountOperation, result: Result<Void, ProfileFailure>)
    case loginCommitted(AuthLoginResult, generation: Int, committed: Bool)
    case staleLoginDiscarded
  }

  @CasePathable
  enum ScopeAction {
    case splash(SplashFeature.Action)
    case home(MainTabCoordinator.Action)
  }

  enum ProfileFailure: Error, Equatable, Sendable {
    case unauthenticated
    case offline
    case termsOutdated
    case unavailable

    init(_ error: Error) {
      if let domain = error as? AuthDomainError, domain == .notAuthenticated {
        self = .unauthenticated
      } else if let network = error as? FestiCoreNetworkError,
                case let .transport(transport) = network {
        switch transport {
        case .notConnected, .timedOut: self = .offline
        case .cancelled, .unknown: self = .unavailable
        }
      } else if let network = error as? FestiCoreNetworkError,
                case let .response(response) = network {
        if response.httpStatus == 401 {
          self = .unauthenticated
        } else if response.httpStatus == 422 && response.code == "TERMS_VERSION_OUTDATED" {
          self = .termsOutdated
        } else {
          self = .unavailable
        }
      } else {
        self = .unavailable
      }
    }
  }

  enum MyAccountOperation: Equatable, Sendable {
    case signOut
    case withdraw
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(state: &state, action: viewAction)
      case let .inner(innerAction):
        return handleInnerAction(state: &state, action: innerAction)
      case let .scope(scopeAction):
        return handleScopeAction(state: &state, action: scopeAction)
      }
    }
    .ifCaseLet(\.splash, action: \.scope.splash) { SplashFeature() }
    .ifCaseLet(\.home, action: \.scope.home) { MainTabCoordinator() }
    .onChange(of: \.festivalSession) { previous, state in
      let session = state.festivalSession
      let changed: Effect<Action> = .send(.scope(.home(.festival(.sessionChanged(
        hasSession: session.hasSession, userID: session.userID
      )))))
      // 로그인 중 확인된 계정 ID가 사라져도(A→nil) 다음에 올 계정이 같다고 보장할 수 없어 전환으로 본다.
      let switchedAccounts = previous.userID != nil && previous.userID != session.userID
      // 깃발 계정 데이터는 여기서만 비운다. `Effect.send`는 같은 send 호출 안에서 처리되어 이전 계정 깃발이 화면에 남지 않는다.
      let flagChanged: Effect<Action> = .send(.scope(.home(.flag(.accountChanged))))
      guard previous.hasSession else {
        // 로그아웃 상태에서 받은 깃발에는 내 팔로우 정보가 없어 로그인한 계정으로 다시 불러온다.
        guard session.hasSession else { return changed }
        return .concatenate(flagChanged, changed)
      }
      if switchedAccounts {
        return .concatenate(
          flagChanged,
          .send(.scope(.home(.timetable(.accountChanged)))),
          changed
        )
      }
      guard !session.hasSession else { return changed }
      return .concatenate(
        flagChanged,
        .send(.scope(.home(.timetable(.accountChanged)))),
        changed
      )
    }
  }
}

private extension AppCoordinator {
  func handleViewAction(state: inout State, action: View) -> Effect<Action> {
    switch action {
    case .presentHome:
      return .send(.inner(.completeHomeTransition))

    case .foregrounded:
      guard case var .home(home) = state,
            home.authFlow.presentation != .login,
            !home.authFlow.isLoading else { return .none }
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      home.authFlow.presentation = nil
      let generation = home.authFlow.generation
      state = .home(home)
      return .merge(
        fetchProfile(generation: generation),
        .send(.scope(.home(.festival(.reloadBookmarks(userID: nil)))))
      )

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
      return .send(.scope(.home(.login(.view(.signIn(provider))))))

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
      home.authFlow.clearConsentAndRetryState()
      let pendingCommit = home.authFlow.pendingCommitSessionID
      home.authFlow.pendingCommitSessionID = nil
      state = .home(home)
      // 확정 전이면 임시 세션을 버리고, 이미 확정됐다면 loginCommitted가 그 세션만 되돌린다.
      guard let pendingCommit else { return .none }
      return .run { _ in _ = await authService.discardSession(pendingCommit) }

    case let .nicknameChanged(nickname):
      guard case var .home(home) = state else { return .none }
      home.authFlow.claimDraft()
      home.authFlow.nickname = nickname
      home.authFlow.nicknameEdited = true
      state = .home(home)
      return .none

    case let .termsAcceptanceChanged(accepted):
      guard case var .home(home) = state else { return .none }
      home.authFlow.claimDraft()
      home.authFlow.acceptedServiceTerms = accepted
      home.authFlow.acceptedPrivacyTerms = accepted
      home.authFlow.syncRequiredTerms()
      state = .home(home)
      return .none

    case let .serviceTermsChanged(accepted):
      guard case var .home(home) = state else { return .none }
      home.authFlow.claimDraft()
      home.authFlow.acceptedServiceTerms = accepted
      home.authFlow.syncRequiredTerms()
      state = .home(home)
      return .none

    case let .privacyTermsChanged(accepted):
      guard case var .home(home) = state else { return .none }
      home.authFlow.claimDraft()
      home.authFlow.acceptedPrivacyTerms = accepted
      home.authFlow.syncRequiredTerms()
      state = .home(home)
      return .none

    case .allConsentToggled:
      guard case var .home(home) = state else { return .none }
      home.authFlow.claimDraft()
      let accepted = !home.authFlow.isAllConsented
      home.authFlow.acceptedServiceTerms = accepted
      home.authFlow.acceptedPrivacyTerms = accepted
      home.authFlow.pushOptIn = accepted
      home.authFlow.syncRequiredTerms()
      state = .home(home)
      return .none

    case let .pushOptInChanged(optedIn):
      guard case var .home(home) = state else { return .none }
      home.authFlow.claimDraft()
      home.authFlow.pushOptIn = optedIn
      state = .home(home)
      return .none

    case .submitOnboarding:
      guard case var .home(home) = state,
            home.authFlow.presentation == .onboarding,
            let profile = home.authFlow.profile,
            home.authFlow.acceptedTerms,
            home.authFlow.consentedVersion == profile.currentTermsVersion,
            !home.authFlow.termsUpdateExhausted,
            !home.authFlow.isLoading else { return .none }
      let nickname = home.authFlow.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
      guard (1 ... 12).contains(nickname.count) else {
        home.authFlow.message = "닉네임은 1~12자로 입력해 주세요."
        state = .home(home)
        return .none
      }
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      let generation = home.authFlow.generation
      let pushOptIn = home.authFlow.pushOptIn
      state = .home(home)
      return .run { send in
        do {
          let user = try await authUseCase.updateProfile(
            nickname: nickname,
            termsVersion: profile.currentTermsVersion,
            pushOptIn: pushOptIn
          )
          await send(.inner(.profileUpdated(generation: generation, .success(user))))
        } catch {
          await send(.inner(.profileUpdated(generation: generation, .failure(ProfileFailure(error)))))
        }
      }

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
        .send(.scope(.home(.festival(.reloadBookmarks(userID: nil)))))
      )

    case let .resolveMigration(accepted):
      guard case var .home(home) = state,
            home.authFlow.presentation == .migration,
            let userID = home.authFlow.verifiedUserID else { return .none }
      bookedStore.resolveLegacyMigration(accepted: accepted, for: userID)
      home.authFlow.presentation = nil
      let pending = home.authFlow.pendingFestivalID
      let shouldBeBooked = home.authFlow.pendingShouldBeBooked
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
      state = .home(home)
      return pending.map { .send(.scope(.home(.completePendingBookmark(id: $0, userID: userID, shouldBeBooked: shouldBeBooked)))) }
        ?? .send(.scope(.home(.festival(.reloadBookmarks(userID: userID)))))

    }
  }

  func handleInnerAction(state: inout State, action: InnerAction) -> Effect<Action> {
    switch action {
    case .completeHomeTransition:
      guard case .splash = state else { return .none }
      state = .home(.init())
      return .merge(
        .send(.view(.foregrounded)),
        .run { send in
          for await _ in authSessionExpiryClient.events() {
            await send(.inner(.sessionExpired))
          }
        }
        .cancellable(id: CancelID.sessionExpiry, cancelInFlight: true)
      )

    case .sessionExpired:
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
      // 프로필 401 처리와 같이, 로그인이 필요해 멈춘 예약이 있으면 유지하고 로그인 시트를 띄운다.
      // 요청 계정을 모르면 다른 계정에 적용되지 않도록 버린다.
      home.authFlow.dropUnownedPendingBookmark()
      if home.authFlow.pendingFestivalID != nil {
        home.authFlow.presentation = .login
      } else if home.authFlow.presentation != .login {
        home.authFlow.presentation = nil
      }
      home.authFlow.clearDraft()
      if interruptedOperation == .withdraw {
        home.authFlow.message = "로그인이 만료되어 회원 탈퇴 결과를 확인할 수 없어요. 다시 로그인해 계정 상태를 확인해 주세요."
      }
      home.profileState = .init()
      let clear = clearAccountData(&home)
      state = .home(home)
      return .merge(clear, .cancel(id: CancelID.accountOperation))

    case let .sessionRestored(generation, userID, isLoggedIn):
      guard case var .home(home) = state,
            home.authFlow.generation == generation else { return .none }
      let shouldClearPreviousAccount = home.authFlow.hasSession && !isLoggedIn
      let eligibleID = userID.flatMap { bookedStore.offlineEligible($0) ? $0 : nil }
      if let ownerID = home.authFlow.pendingOwnerID,
         let userID,
         ownerID != userID {
        home.authFlow.pendingFestivalID = nil
        home.authFlow.pendingOwnerID = nil
      }
      // 세션이 끊길 때 요청 계정을 모르는 예약은 sessionExpired와 같이 버린다.
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
        .send(.scope(.home(.festival(.reloadBookmarks(userID: eligibleID)))))
      )

    case let .profileLoaded(generation, result):
      guard case var .home(home) = state,
            home.authFlow.generation == generation else { return .none }
      home.authFlow.isLoading = false
      switch result {
      case let .success(profile):
        bookedStore.setOfflineEligible(profile.user.id, profile.isEligible)
        if let oldID = home.authFlow.verifiedUserID, oldID != profile.user.id {
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
          home.authFlow.clearDraft()
        }
        if let oldID = home.authFlow.lastVerifiedUserID, oldID != profile.user.id {
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
          home.authFlow.clearDraft()
        }
        home.authFlow.reconcileDraft(userID: profile.user.id)
        if let ownerID = home.authFlow.pendingOwnerID, ownerID != profile.user.id {
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
        }
        home.authFlow.profile = profile
        home.authFlow.verifiedUserID = profile.user.id
        home.authFlow.lastVerifiedUserID = profile.user.id
        home.authFlow.hasSession = true
        if profile.isEligible {
          return finishEligible(state: &state, home: &home)
        }
        home.authFlow.presentation = .onboarding
        if !home.authFlow.nicknameEdited, home.authFlow.nickname.isEmpty,
           let nickname = profile.user.nickname, !nickname.isEmpty {
          home.authFlow.nickname = nickname
          home.authFlow.claimDraft()
        }
        // 약관 버전이 바뀌면 이전 버전에 체크한 필수 항목을 모두 지운다.
        if let draftVersion = home.authFlow.termsDraftVersion, draftVersion != profile.currentTermsVersion {
          home.authFlow.clearRequiredTerms()
        }
        home.authFlow.acceptedTerms = home.authFlow.acceptedTerms
          && home.authFlow.consentedVersion == profile.currentTermsVersion
        if !home.authFlow.acceptedTerms { home.authFlow.consentedVersion = nil }
        home.authFlow.message = home.authFlow.hasRetriedTermsUpdate
          ? "변경된 약관을 확인하고 다시 동의해 주세요."
          : nil
        state = .home(home)
        return .send(.scope(.home(.festival(.reloadBookmarks(userID: nil)))))

      case .failure(.unauthenticated):
        let hadSession = home.authFlow.hasSession
        home.authFlow.verifiedUserID = nil
        home.authFlow.lastVerifiedUserID = nil
        home.authFlow.hasSession = false
        home.authFlow.profile = nil
        // 로그인을 잃으면 다른 계정이 이어받지 않도록 가입 초안과 소유자 없는 대기 예약을 지운다.
        home.authFlow.clearDraft()
        home.authFlow.dropUnownedPendingBookmark()
        home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .login
        // 같은 로그아웃을 `sessionRestored`가 이미 비웠다면 그 뒤 받은 비로그인 라이브 보드를 다시 지우지 않고 예약 목록만 정리한다.
        let clear = hadSession
          ? clearAccountData(&home)
          : .send(.scope(.home(.festival(.accountChanged))))
        state = .home(home)
        return clear

      case .failure(.offline):
        home.authFlow.profile = nil
        if let userID = home.authFlow.verifiedUserID,
           bookedStore.offlineEligible(userID),
           let pending = home.authFlow.pendingFestivalID {
          let shouldBeBooked = home.authFlow.pendingShouldBeBooked
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
          home.authFlow.presentation = nil
          state = .home(home)
          return .send(.scope(.home(.completePendingBookmark(
            id: pending, userID: userID, shouldBeBooked: shouldBeBooked
          ))))
        }
        home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .retry
        if home.authFlow.presentation == .retry {
          home.authFlow.message = "오프라인에서 계정 정보를 확인할 수 없어요. 연결 후 다시 시도해 주세요."
        }
        state = .home(home)
        return .none

      case .failure:
        home.authFlow.profile = nil
        home.authFlow.verifiedUserID = nil
        home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .retry
        home.authFlow.message = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
        state = .home(home)
        return .send(.scope(.home(.festival(.reloadBookmarks(userID: nil)))))
      }

    case let .profileUpdated(generation, result):
      guard case var .home(home) = state,
            home.authFlow.generation == generation,
            let previous = home.authFlow.profile else { return .none }
      home.authFlow.isLoading = false
      switch result {
      case let .success(user):
        guard user.id == previous.user.id else {
          // 다른 계정 응답은 신뢰하지 않는다. 계정 ID를 모두 지워 세션 변경 감지가 이전 계정 데이터를 비우게 한다.
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
          home.authFlow.clearDraft()
          home.authFlow.presentation = nil
          home.authFlow.verifiedUserID = nil
          home.authFlow.lastVerifiedUserID = nil
          home.authFlow.profile = nil
          state = .home(home)
          return .none
        }
        let profile = AuthProfile(user: user, currentTermsVersion: previous.currentTermsVersion)
        home.authFlow.profile = profile
        if profile.isEligible {
          return finishEligible(state: &state, home: &home)
        }
        home.authFlow.message = "필수 정보가 확인되지 않았어요. 다시 시도해 주세요."
        state = .home(home)
        return .none

      case .failure(.termsOutdated):
        guard !home.authFlow.hasRetriedTermsUpdate else {
          home.authFlow.termsUpdateExhausted = true
          home.authFlow.clearRequiredTerms()
          home.authFlow.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
          state = .home(home)
          return .none
        }
        home.authFlow.hasRetriedTermsUpdate = true
        home.authFlow.clearRequiredTerms()
        home.authFlow.message = "약관이 변경됐어요. 내용을 확인하고 다시 동의해 주세요."
        home.authFlow.generation += 1
        home.authFlow.isLoading = true
        let nextGeneration = home.authFlow.generation
        state = .home(home)
        return fetchProfile(generation: nextGeneration)

      case .failure(.unauthenticated):
        home.authFlow.verifiedUserID = nil
        home.authFlow.lastVerifiedUserID = nil
        home.authFlow.hasSession = false
        home.authFlow.profile = nil
        home.authFlow.clearDraft()
        home.authFlow.dropUnownedPendingBookmark()
        home.authFlow.presentation = .login
        let clear = clearAccountData(&home)
        state = .home(home)
        return clear

      case .failure(.offline):
        home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
        state = .home(home)
        return .none

      case .failure(.unavailable):
        home.authFlow.message = "저장하지 못했어요. 다시 시도해 주세요."
        state = .home(home)
        return .none
      }

    case let .loginCommitted(result, generation, committed):
      guard case var .home(home) = state else { return .none }
      if home.authFlow.generation == generation, isActiveLoginAttempt(home.authFlow) {
        home.authFlow.pendingCommitSessionID = nil
        state = .home(home)
        if committed { return acceptLogin(result, state: &state) }
        // 저장에 실패한 로그인은 시트를 유지해 다시 시도할 수 있게 한다.
        home.authFlow.loginAttemptGeneration = nil
        home.authFlow.isLoading = false
        home.authFlow.message = "로그인 정보를 저장하지 못했어요. 다시 시도해 주세요."
        state = .home(home)
        return .none
      }
      // 확정하는 사이 시트가 닫혔다. 닫은 로그인의 세션은 그 식별자일 때만 되돌린다.
      guard committed, let sessionID = result.sessionID else { return .none }
      return .run { send in
        if await authService.signOut(ifSession: sessionID) {
          await send(.inner(.staleLoginDiscarded))
        }
      }

    case .staleLoginDiscarded:
      // 그 사이 포그라운드 복원이 되돌린 세션을 화면에 반영했다면 저장소 상태를 다시 읽는다.
      guard case var .home(home) = state,
            home.authFlow.hasSession,
            home.authFlow.loginAttemptGeneration == nil,
            home.authFlow.accountOperationGeneration == nil else { return .none }
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      let next = home.authFlow.generation
      state = .home(home)
      return fetchProfile(generation: next)

    case let .myAccountFinished(generation, operation, result):
      guard case var .home(home) = state,
            home.authFlow.accountOperationGeneration == generation else { return .none }
      home.authFlow.accountOperationGeneration = nil
      home.authFlow.accountOperation = nil
      home.authFlow.isLoading = false
      switch result {
      case .success:
        var cleared = AuthFlow()
        cleared.generation = max(home.authFlow.generation, generation)
        home.authFlow = cleared
        home.profileState = .init()
        let clear = clearAccountData(&home)
        state = .home(home)
        return clear
      case .failure(.unauthenticated):
        var cleared = AuthFlow()
        cleared.generation = max(home.authFlow.generation, generation)
        if operation == .withdraw {
          cleared.message = "로그인이 만료되어 회원 탈퇴 결과를 확인할 수 없어요. 다시 로그인해 계정 상태를 확인해 주세요."
        }
        home.authFlow = cleared
        home.profileState = .init()
        let clear = clearAccountData(&home)
        state = .home(home)
        return clear
      case .failure:
        home.authFlow.message = operation == .withdraw
          ? "회원 탈퇴에 실패했습니다. 다시 시도해 주세요."
          : "로그아웃에 실패했습니다. 다시 시도해 주세요."
        state = .home(home)
        return .none
      }
    }
  }

  func handleScopeAction(state: inout State, action: ScopeAction) -> Effect<Action> {
    switch action {
    case .splash(.delegate(.presentHome)):
      return .send(.view(.presentHome))

    case let .home(.festival(.delegate(.bookmarkRequested(id)))):
      guard case var .home(home) = state,
            home.authFlow.accountOperationGeneration == nil else { return .none }
      home.authFlow.generation += 1
      home.authFlow.pendingFestivalID = id
      if let userID = home.authFlow.verifiedUserID,
         home.authFlow.profile?.isEligible == true {
        home.authFlow.pendingShouldBeBooked = !bookedStore.load(for: userID).contains(id)
      } else {
        home.authFlow.pendingShouldBeBooked = !isBooked(id, in: home.festivalState)
      }
      home.authFlow.pendingOwnerID = home.authFlow.verifiedUserID ?? home.authFlow.lastVerifiedUserID
      home.authFlow.message = nil
      home.authFlow.hasRetriedTermsUpdate = false
      home.authFlow.termsUpdateExhausted = false
      let generation = home.authFlow.generation
      home.authFlow.isLoading = true
      state = .home(home)
      return fetchProfile(generation: generation)

    case let .home(.login(.delegate(.signedIn(result)))):
      guard case let .home(home) = state else { return .none }
      let accepted = isActiveLoginAttempt(home.authFlow)
      guard let sessionID = result.sessionID else {
        return accepted ? acceptLogin(result, state: &state) : .none
      }
      guard accepted else {
        // 시트를 닫은 뒤 끝난 로그인은 확정하지 않고 그 임시 세션만 버린다.
        return .run { _ in _ = await authService.discardSession(sessionID) }
      }
      var accepting = home
      accepting.authFlow.pendingCommitSessionID = sessionID
      state = .home(accepting)
      let generation = home.authFlow.generation
      return .run { send in
        let committed = await authService.commitSession(sessionID)
        await send(.inner(.loginCommitted(result, generation: generation, committed: committed)))
      }

    case .home(.delegate(.myLoginRequested)):
      guard case var .home(home) = state,
            !home.authFlow.isLoading else { return .none }
      home.authFlow.generation += 1
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
      home.authFlow.message = nil
      home.authFlow.presentation = .login
      state = .home(home)
      return .none

    case .home(.delegate(.myProfileRefreshRequested)):
      return .send(.view(.retryProfile))

    case .home(.delegate(.myLogoutRequested)):
      return myAccountOperation(state: &state, operation: .signOut)

    case .home(.delegate(.myWithdrawRequested)):
      return myAccountOperation(state: &state, operation: .withdraw)

    default:
      return .none
    }
  }

  func myAccountOperation(
    state: inout State,
    operation: MyAccountOperation
  ) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.hasSession,
          !home.authFlow.isLoading else { return .none }
    home.authFlow.generation += 1
    home.authFlow.accountOperationGeneration = home.authFlow.generation
    home.authFlow.accountOperation = operation
    home.authFlow.isLoading = true
    home.authFlow.message = nil
    let generation = home.authFlow.generation
    state = .home(home)
    return .run { send in
      do {
        switch operation {
        case .signOut: try await authUseCase.signOut()
        case .withdraw: try await authUseCase.withdraw()
        }
        await send(.inner(.myAccountFinished(generation: generation, operation: operation, result: .success(()))))
      } catch {
        if !(await authService.isLoggedIn) {
          await send(.inner(.sessionExpired))
          return
        }
        await send(.inner(.myAccountFinished(
          generation: generation, operation: operation, result: .failure(ProfileFailure(error))
        )))
      }
    }
    .cancellable(id: CancelID.accountOperation, cancelInFlight: true)
  }

  func fetchProfile(generation: Int) -> Effect<Action> {
    .run { send in
      let isLoggedIn = await authService.isLoggedIn
      let userID = await authService.currentUserID
      await send(.inner(.sessionRestored(generation: generation, userID: userID, isLoggedIn: isLoggedIn)))
      guard isLoggedIn else {
        await send(.inner(.profileLoaded(generation: generation, .failure(.unauthenticated))))
        return
      }
      do {
        let profile = try await authUseCase.fetchProfile()
        await send(.inner(.profileLoaded(generation: generation, .success(profile))))
      } catch {
        await send(.inner(.profileLoaded(generation: generation, .failure(ProfileFailure(error)))))
      }
    }
  }

  /// 시트가 열려 있고 현재 세대의 로그인 시도일 때만 결과를 받아들인다.
  func isActiveLoginAttempt(_ flow: AuthFlow) -> Bool {
    flow.presentation == .login && flow.loginAttemptGeneration == flow.generation
  }

  func acceptLogin(_ result: AuthLoginResult, state: inout State) -> Effect<Action> {
    guard case var .home(home) = state else { return .none }
      if let oldID = home.authFlow.verifiedUserID, oldID != result.user.id {
        home.authFlow.pendingFestivalID = nil
        home.authFlow.pendingOwnerID = nil
      }
      if let oldID = home.authFlow.lastVerifiedUserID, oldID != result.user.id {
        home.authFlow.pendingFestivalID = nil
        home.authFlow.pendingOwnerID = nil
      }
      if let ownerID = home.authFlow.pendingOwnerID, ownerID != result.user.id {
        home.authFlow.pendingFestivalID = nil
        home.authFlow.pendingOwnerID = nil
      }
      home.authFlow.verifiedUserID = result.user.id
      home.authFlow.hasSession = true
      home.authFlow.profile = nil
      home.authFlow.presentation = nil
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      let generation = home.authFlow.generation
      state = .home(home)
      return fetchProfile(generation: generation)
  }

  func finishEligible(state: inout State, home: inout MainTabCoordinator.State) -> Effect<Action> {
    guard let profile = home.authFlow.profile, profile.isEligible else { return .none }
    let userID = profile.user.id
    bookedStore.setOfflineEligible(userID, true)
    home.authFlow.verifiedUserID = userID
    home.authFlow.lastVerifiedUserID = userID
    home.authFlow.hasRetriedTermsUpdate = false
    home.authFlow.termsUpdateExhausted = false
    home.authFlow.message = nil
    if !bookedStore.legacyBookmarks().isEmpty {
      home.authFlow.presentation = .migration
      state = .home(home)
      return .none
    }
    home.authFlow.presentation = nil
    let pending = home.authFlow.pendingFestivalID
    let shouldBeBooked = home.authFlow.pendingShouldBeBooked
    home.authFlow.pendingFestivalID = nil
    home.authFlow.pendingOwnerID = nil
    state = .home(home)
    return pending.map { .send(.scope(.home(.completePendingBookmark(id: $0, userID: userID, shouldBeBooked: shouldBeBooked)))) }
      ?? .send(.scope(.home(.festival(.reloadBookmarks(userID: userID)))))
  }

  /// 이전 계정의 라이브 보드·예약 목록을 바로 비운다.
  func clearAccountData(_ home: inout MainTabCoordinator.State) -> Effect<Action> {
    // 세션이 이미 끊긴 뒤 처리되는 `accountChanged`는 예약 목록만 비우므로 라이브 보드 개인 데이터는 여기서 바로 지운다.
    // 자식 액션은 진행 중 요청 취소와 새 계정 갱신을 맡는다. 깃발은 세션 변경 감지에서 비운다.
    home.festivalState.clearAccountData()
    return .send(.scope(.home(.festival(.accountChanged))))
  }

  func isBooked(_ id: String, in festival: FestivalCoordinator.State) -> Bool {
    guard let screen = festival.routes.last?.screen else { return false }
    switch screen {
    case let .festivalList(list): return list.bookedFestivalIDs.contains(id)
    case let .liveBoard(board): return board.bookedFestivalIDs.contains(id)
    }
  }
}
