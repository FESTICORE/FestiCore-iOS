//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import Foundation

@Reducer
struct AppCoordinator {
  @Dependency(\.authUseCase) private var authUseCase
  @Dependency(\.authService) private var authService
  @Dependency(\.festivalBookedStore) private var bookedStore

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
    var loginAttemptGeneration: Int?
    var verifiedUserID: String?
    var lastVerifiedUserID: String?
    var profile: AuthProfile?
    var presentation: Presentation?
    var nickname = ""
    var acceptedTerms = false
    var consentedVersion: String?
    var pushOptIn = false
    var isLoading = false
    var hasRetriedTermsUpdate = false
    var termsUpdateExhausted = false
    var message: String?
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
    case pushOptInChanged(Bool)
    case submitOnboarding
    case retryProfile
    case resolveMigration(Bool)
  }

  @CasePathable
  enum InnerAction {
    case completeHomeTransition
    case sessionRestored(generation: Int, userID: String?)
    case profileLoaded(generation: Int, Result<AuthProfile, ProfileFailure>)
    case profileUpdated(generation: Int, Result<AuthUser, ProfileFailure>)
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
      guard case var .home(home) = state,
            home.authFlow.presentation == .login,
            !home.loginState.isSigningIn else { return .none }
      home.authFlow.loginAttemptGeneration = home.authFlow.generation
      state = .home(home)
      return .send(.scope(.home(.login(.view(.signIn(provider))))))

    case .dismissFlow:
      guard case var .home(home) = state else { return .none }
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
      home.authFlow.generation += 1
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.presentation = nil
      home.authFlow.message = nil
      home.authFlow.hasRetriedTermsUpdate = false
      home.authFlow.termsUpdateExhausted = false
      home.authFlow.acceptedTerms = false
      home.authFlow.consentedVersion = nil
      state = .home(home)
      return .none

    case let .nicknameChanged(nickname):
      guard case var .home(home) = state else { return .none }
      home.authFlow.nickname = nickname
      state = .home(home)
      return .none

    case let .termsAcceptanceChanged(accepted):
      guard case var .home(home) = state else { return .none }
      home.authFlow.acceptedTerms = accepted
      home.authFlow.consentedVersion = accepted ? home.authFlow.profile?.currentTermsVersion : nil
      state = .home(home)
      return .none

    case let .pushOptInChanged(optedIn):
      guard case var .home(home) = state else { return .none }
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
      return .send(.view(.foregrounded))

    case let .sessionRestored(generation, userID):
      guard case var .home(home) = state,
            home.authFlow.generation == generation else { return .none }
      let eligibleID = userID.flatMap { bookedStore.offlineEligible($0) ? $0 : nil }
      if let ownerID = home.authFlow.pendingOwnerID,
         let userID,
         ownerID != userID {
        home.authFlow.pendingFestivalID = nil
        home.authFlow.pendingOwnerID = nil
      }
      home.authFlow.verifiedUserID = eligibleID
      if let userID { home.authFlow.lastVerifiedUserID = userID }
      state = .home(home)
      return .send(.scope(.home(.festival(.reloadBookmarks(userID: eligibleID)))))

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
          home.authFlow.nickname = ""
          home.authFlow.acceptedTerms = false
          home.authFlow.consentedVersion = nil
        }
        if let oldID = home.authFlow.lastVerifiedUserID, oldID != profile.user.id {
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
          home.authFlow.nickname = ""
          home.authFlow.acceptedTerms = false
          home.authFlow.consentedVersion = nil
        }
        if let ownerID = home.authFlow.pendingOwnerID, ownerID != profile.user.id {
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
        }
        home.authFlow.profile = profile
        home.authFlow.verifiedUserID = profile.user.id
        home.authFlow.lastVerifiedUserID = profile.user.id
        if profile.isEligible {
          return finishEligible(state: &state, home: &home)
        }
        home.authFlow.presentation = .onboarding
        if home.authFlow.nickname.isEmpty {
          home.authFlow.nickname = profile.user.nickname ?? ""
        }
        home.authFlow.acceptedTerms = home.authFlow.acceptedTerms
          && home.authFlow.consentedVersion == profile.currentTermsVersion
        home.authFlow.message = home.authFlow.hasRetriedTermsUpdate
          ? "변경된 약관을 확인하고 다시 동의해 주세요."
          : nil
        state = .home(home)
        return .send(.scope(.home(.festival(.reloadBookmarks(userID: nil)))))

      case .failure(.unauthenticated):
        home.authFlow.verifiedUserID = nil
        home.authFlow.profile = nil
        home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .login
        state = .home(home)
        return .send(.scope(.home(.festival(.reloadBookmarks(userID: nil)))))

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
          home.authFlow.pendingFestivalID = nil
          home.authFlow.pendingOwnerID = nil
          home.authFlow.presentation = nil
          home.authFlow.verifiedUserID = nil
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
          home.authFlow.acceptedTerms = false
          home.authFlow.consentedVersion = nil
          home.authFlow.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
          state = .home(home)
          return .none
        }
        home.authFlow.hasRetriedTermsUpdate = true
        home.authFlow.acceptedTerms = false
        home.authFlow.consentedVersion = nil
        home.authFlow.message = "약관이 변경됐어요. 내용을 확인하고 다시 동의해 주세요."
        home.authFlow.generation += 1
        home.authFlow.isLoading = true
        let nextGeneration = home.authFlow.generation
        state = .home(home)
        return fetchProfile(generation: nextGeneration)

      case .failure(.unauthenticated):
        home.authFlow.verifiedUserID = nil
        home.authFlow.profile = nil
        home.authFlow.presentation = .login
        state = .home(home)
        return .none

      case .failure(.offline):
        home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
        state = .home(home)
        return .none

      case .failure(.unavailable):
        home.authFlow.message = "저장하지 못했어요. 다시 시도해 주세요."
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
      guard case var .home(home) = state else { return .none }
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
      guard case var .home(home) = state,
            home.authFlow.presentation == .login,
            home.authFlow.loginAttemptGeneration == home.authFlow.generation else { return .none }
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
      home.authFlow.profile = nil
      home.authFlow.presentation = nil
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      let generation = home.authFlow.generation
      state = .home(home)
      return fetchProfile(generation: generation)

    default:
      return .none
    }
  }

  func fetchProfile(generation: Int) -> Effect<Action> {
    .run { send in
      await send(.inner(.sessionRestored(generation: generation, userID: await authService.currentUserID)))
      do {
        let profile = try await authUseCase.fetchProfile()
        await send(.inner(.profileLoaded(generation: generation, .success(profile))))
      } catch {
        await send(.inner(.profileLoaded(generation: generation, .failure(ProfileFailure(error)))))
      }
    }
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

  func isBooked(_ id: String, in festival: FestivalCoordinator.State) -> Bool {
    guard let screen = festival.routes.last?.screen else { return false }
    switch screen {
    case let .festivalList(list): return list.bookedFestivalIDs.contains(id)
    case let .liveBoard(board): return board.bookedFestivalIDs.contains(id)
    }
  }
}
