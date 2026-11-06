//
//  AppCoordinator+ProfileAction.swift
//  FestiCore
//

import AuthDomainInterface
import ComposableArchitecture
import FestivalDomainInterface

extension AppCoordinator {
  func handleProfileLoaded(
    state: inout State,
    generation: Int,
    result: Result<AuthProfile, ProfileFailure>
  ) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.generation == generation else { return .none }
    home.authFlow.isLoading = false
    switch result {
    case let .success(profile):
      return handleLoadedProfile(
        profile,
        state: &state,
        home: &home
      )

    case let .failure(failure):
      return handleProfileLoadFailure(
        failure,
        state: &state,
        home: &home
      )
    }
  }

  private func handleLoadedProfile(
    _ profile: AuthProfile,
    state: inout State,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    festivalLibraryUseCase.setOfflineBookingEligibility(
      profile.isEligible,
      for: profile.user.id
    )
    if home.authFlow.verifiedUserID != nil, home.authFlow.verifiedUserID != profile.user.id {
      clearPendingAccountData(&home.authFlow)
    }
    if home.authFlow.lastVerifiedUserID != nil, home.authFlow.lastVerifiedUserID != profile.user.id {
      clearPendingAccountData(&home.authFlow)
    }
    home.authFlow.reconcileSignUpDraft(userID: profile.user.id)
    if let ownerID = home.authFlow.pendingOwnerID, ownerID != profile.user.id {
      clearPendingBookmark(&home.authFlow)
    }
    home.authFlow.profile = profile
    home.authFlow.verifiedUserID = profile.user.id
    home.authFlow.lastVerifiedUserID = profile.user.id
    home.authFlow.hasSession = true
    guard !profile.isEligible else {
      return finishEligible(
        state: &state,
        home: &home
      )
    }
    home.authFlow.presentation = .onboarding
    home.authFlow.signUp.apply(
      profileUserID: profile.user.id,
      serverNickname: profile.user.nickname,
      termsVersion: profile.currentTermsVersion
    )
    home.authFlow.message = home.authFlow.hasRetriedTermsUpdate
      ? "변경된 약관을 확인하고 다시 동의해 주세요."
      : nil
    state = .home(home)
    return .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: nil))))))
  }

  private func handleProfileLoadFailure(
    _ failure: ProfileFailure,
    state: inout State,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    switch failure {
    case .unauthenticated:
      let hadSession = home.authFlow.hasSession
      home.authFlow.verifiedUserID = nil
      home.authFlow.lastVerifiedUserID = nil
      home.authFlow.hasSession = false
      home.authFlow.profile = nil
      home.authFlow.clearSignUpDraft()
      if hadSession { home.authFlow.dropUnownedPendingBookmark() }
      home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .login
      let clear = hadSession
        ? clearAccountData(&home)
        : .send(.scope(.home(.scopeAction(.festival(.accountChanged)))))
      state = .home(home)
      return clear

    case .offline:
      home.authFlow.profile = nil
      if let userID = home.authFlow.verifiedUserID,
         festivalLibraryUseCase.isOfflineBookingEligible(userID: userID),
         let pending = home.authFlow.pendingFestivalID {
        let shouldBeBooked = home.authFlow.pendingShouldBeBooked
        clearPendingBookmark(&home.authFlow)
        home.authFlow.presentation = nil
        state = .home(home)
        return .send(.scope(.home(.completePendingBookmark(
          id: pending,
          userID: userID,
          shouldBeBooked: shouldBeBooked
        ))))
      }
      home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .retry
      if home.authFlow.presentation == .retry {
        home.authFlow.message = "오프라인에서 계정 정보를 확인할 수 없어요. 연결 후 다시 시도해 주세요."
      }
      state = .home(home)
      return .none

    case .termsOutdated, .unavailable:
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      home.authFlow.presentation = home.authFlow.pendingFestivalID == nil ? nil : .retry
      home.authFlow.message = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
      state = .home(home)
      return .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: nil))))))
    }
  }

  func handleProfileUpdated(
    state: inout State,
    generation: Int,
    result: Result<AuthUser, ProfileFailure>
  ) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.generation == generation,
          let previous = home.authFlow.profile else { return .none }
    home.authFlow.isLoading = false
    switch result {
    case let .success(user):
      guard user.id == previous.user.id else {
        clearPendingAccountData(&home.authFlow)
        home.authFlow.clearSignUpDraft()
        home.authFlow.presentation = nil
        home.authFlow.verifiedUserID = nil
        home.authFlow.lastVerifiedUserID = nil
        home.authFlow.profile = nil
        state = .home(home)
        return .none
      }
      let profile = AuthProfile(
        user: user,
        currentTermsVersion: previous.currentTermsVersion
      )
      home.authFlow.profile = profile
      if profile.isEligible {
        return finishEligible(
          state: &state,
          home: &home
        )
      }
      home.authFlow.message = "필수 정보가 확인되지 않았어요. 다시 시도해 주세요."
      state = .home(home)
      return .none

    case let .failure(failure):
      return handleProfileUpdateFailure(
        failure,
        state: &state,
        home: &home
      )
    }
  }

  private func handleProfileUpdateFailure(
    _ failure: ProfileFailure,
    state: inout State,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    switch failure {
    case .termsOutdated:
      guard !home.authFlow.hasRetriedTermsUpdate else {
        home.authFlow.termsUpdateExhausted = true
        home.authFlow.signUp.clearRequiredTerms()
        home.authFlow.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
        state = .home(home)
        return .none
      }
      home.authFlow.hasRetriedTermsUpdate = true
      home.authFlow.signUp.clearRequiredTerms()
      home.authFlow.message = "약관이 변경됐어요. 내용을 확인하고 다시 동의해 주세요."
      home.authFlow.generation += 1
      home.authFlow.isLoading = true
      let nextGeneration = home.authFlow.generation
      state = .home(home)
      return fetchProfile(generation: nextGeneration)

    case .unauthenticated:
      home.authFlow.verifiedUserID = nil
      home.authFlow.lastVerifiedUserID = nil
      home.authFlow.hasSession = false
      home.authFlow.profile = nil
      home.authFlow.clearSignUpDraft()
      home.authFlow.dropUnownedPendingBookmark()
      home.authFlow.presentation = .login
      let clear = clearAccountData(&home)
      state = .home(home)
      return clear

    case .offline:
      home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
      state = .home(home)
      return .none

    case .unavailable:
      home.authFlow.message = "저장하지 못했어요. 다시 시도해 주세요."
      state = .home(home)
      return .none
    }
  }

  func finishEligible(
    state: inout State,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    guard let profile = home.authFlow.profile, profile.isEligible else { return .none }
    let userID = profile.user.id
    festivalLibraryUseCase.setOfflineBookingEligibility(
      true,
      for: userID
    )
    home.authFlow.verifiedUserID = userID
    home.authFlow.lastVerifiedUserID = userID
    home.authFlow.hasRetriedTermsUpdate = false
    home.authFlow.termsUpdateExhausted = false
    home.authFlow.message = nil
    if !festivalLibraryUseCase.legacyBookmarks().isEmpty {
      home.authFlow.presentation = .migration
      state = .home(home)
      return .none
    }
    home.authFlow.presentation = nil
    let pending = home.authFlow.pendingFestivalID
    let shouldBeBooked = home.authFlow.pendingShouldBeBooked
    clearPendingBookmark(&home.authFlow)
    state = .home(home)
    if let pending {
      return .send(.scope(.home(.completePendingBookmark(
        id: pending,
        userID: userID,
        shouldBeBooked: shouldBeBooked
      ))))
    }
    return .send(.scope(.home(.scopeAction(.festival(.reloadBookmarks(userID: userID))))))
  }

  private func clearPendingAccountData(_ flow: inout AuthFlow) {
    clearPendingBookmark(&flow)
    flow.clearSignUpDraft()
  }

  func clearPendingBookmark(_ flow: inout AuthFlow) {
    flow.pendingFestivalID = nil
    flow.pendingOwnerID = nil
  }
}
