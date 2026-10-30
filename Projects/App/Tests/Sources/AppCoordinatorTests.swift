//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Foundation
import Testing

import ComposableArchitecture
import AuthDomainInterface
import FeatureAssembly
import FestivalDomainInterface
import FestiCoreNetworkInterface
import TCAFlow
@testable import FestiCore

@MainActor
struct AppCoordinatorTests {
  @Test func startsAtSplash() {
    #expect(AppCoordinator.State() == .splash(.init()))
  }

  @Test func legalLinksUseConfiguredAPIHost() {
    let base = AppCoordinatorView.legalBaseURL(host: "festicore-dev.up.railway.app")
    #expect(base?.appending(path: "terms").absoluteString
      == "https://festicore-dev.up.railway.app/api/v1/legal/terms")
    #expect(base?.appending(path: "privacy").absoluteString
      == "https://festicore-dev.up.railway.app/api/v1/legal/privacy")
    #expect(AppCoordinatorView.legalBaseURL(host: nil) == nil)
  }

  @Test func splashCompletionShowsHome() async {
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
    }
    store.exhaustivity = .off
    await store.send(.scope(.splash(.delegate(.presentHome))))
    await store.receive(\.view.presentHome)
    await store.receive(\.inner.completeHomeTransition) {
      $0 = .home(.init())
    }
  }

  @Test func repeatedHomeTransitionKeepsExistingState() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalCatalogService = EmptyFestivalCatalogService()
    }
    await store.send(.inner(.completeHomeTransition))
  }

  @Test func unauthenticatedBookmarkOpensLoginWithoutSaving() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = UnauthenticatedAuthUseCase()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival")))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
  }

  @Test func offlineRestartRestoresAndSavesOnlyTheCurrentAccountsBookmarks() async {
    let box = BookmarkBox(ids: ["saved"])
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.pendingFestivalID = "new"
    home.authFlow.pendingOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in userID == "user-a" ? box.ids : [] },
        save: { ids, userID in if userID == "user-a" { box.ids = ids } },
        offlineEligible: { $0 == "user-a" }
      )
    }
    store.exhaustivity = .off

    await store.send(.inner(.sessionRestored(generation: 1, userID: "user-a")))
    await store.send(.inner(.profileLoaded(generation: 1, .failure(.offline))))
    await store.receive(\.scope.home.completePendingBookmark)
    #expect(box.ids == ["saved", "new"])
    guard case let .home(restored) = store.state else { return }
    #expect(restored.authFlow.verifiedUserID == "user-a")
  }

  @Test func accountSwitchAndLogoutDiscardPreviousAccountsPendingBookmark() async {
    let box = BookmarkBox(ids: ["saved-a"])
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.pendingFestivalID = "new"
    home.authFlow.pendingOwnerID = "user-a"
    home.authFlow.verifiedUserID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in userID == "user-a" ? box.ids : ["saved-b"] },
        save: { ids, userID in if userID == "user-a" { box.ids = ids } },
        offlineEligible: { _ in true }
      )
    }
    store.exhaustivity = .off

    await store.send(.inner(.sessionRestored(generation: 1, userID: "user-b")))
    await store.send(.inner(.profileLoaded(generation: 1, .failure(.offline))))
    guard case let .home(switched) = store.state else { return }
    #expect(switched.authFlow.pendingFestivalID == nil)
    #expect(switched.authFlow.verifiedUserID == "user-b")
    #expect(box.ids == ["saved-a"])

    await store.send(.inner(.sessionRestored(generation: 1, userID: nil)))
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.authFlow.verifiedUserID == nil)
    #expect(box.ids == ["saved-a"])
  }

  @Test(arguments: [ProfileStubFailure.server, .missingVersion])
  func foregroundFailureDoesNotReuseCachedEligibility(failure: ProfileStubFailure) async {
    let box = BookmarkBox(ids: [])
    var home = MainTabCoordinator.State()
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = FailingProfileAuthUseCase(failure: failure)
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in box.ids },
        save: { ids, _ in box.ids = ids }
      )
    }
    store.exhaustivity = .off

    await store.send(.view(.foregrounded)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.isLoading = true
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.message = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival")))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.pendingOwnerID = "user-a"
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.presentation = .retry
      home.authFlow.message = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
      $0 = .home(home)
    }
    #expect(box.ids.isEmpty)
  }

  @Test func accountSwitchDuringForegroundValidationDiscardsPendingBookmark() async {
    let box = BookmarkBox(ids: [])
    var home = MainTabCoordinator.State()
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-b"))
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in box.ids },
        save: { ids, _ in box.ids = ids }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival")))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.pendingOwnerID = "user-a"
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
      home.authFlow.profile = eligibleProfile(id: "user-b")
      home.authFlow.verifiedUserID = "user-b"
      home.authFlow.lastVerifiedUserID = "user-b"
      $0 = .home(home)
    }
    #expect(box.ids.isEmpty)
  }

  @Test func cancellingLoginInvalidatesLateSuccess() async {
    let box = BookmarkBox(ids: [])
    var home = MainTabCoordinator.State()
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.generation = 1
    home.authFlow.loginAttemptGeneration = 1
    home.authFlow.presentation = .login
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in box.ids },
        save: { ids, _ in box.ids = ids }
      )
    }

    await store.send(.view(.dismissFlow)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.pendingFestivalID = nil
      home.authFlow.generation = 2
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    let result = AuthLoginResult(newUser: false, user: eligibleProfile(id: "user-a").user)
    await store.send(.scope(.home(.login(.delegate(.signedIn(result))))))
    #expect(box.ids.isEmpty)
  }

  @Test func profileUpdate401KeepsPendingBookmarkForSameAccountLogin() async {
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: nil,
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
    var home = MainTabCoordinator.State()
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingOwnerID = "user-a"
    home.authFlow.generation = 1
    home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    }

    await store.send(.inner(.profileUpdated(generation: 1, .failure(.unauthenticated)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.verifiedUserID = nil
      home.authFlow.profile = nil
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    guard case let .home(current) = store.state else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(current.authFlow.pendingFestivalID == "festival")
    #expect(current.authFlow.pendingOwnerID == "user-a")
  }

  @Test func offlineProfileUpdateKeepsPendingActionForRetry() async {
    var home = MainTabCoordinator.State()
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingOwnerID = "user-a"
    home.authFlow.generation = 1
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    }

    await store.send(.inner(.profileUpdated(generation: 1, .failure(.offline)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
      $0 = .home(home)
    }
    guard case let .home(current) = store.state else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(current.authFlow.pendingFestivalID == "festival")
    #expect(current.authFlow.pendingOwnerID == "user-a")
  }

  @Test func outdatedTermsRequiresRefetchAndFreshConsent() async {
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: "테스터",
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
    var home = MainTabCoordinator.State()
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.generation = 1
    home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-09")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.nickname = "테스터"
    home.authFlow.acceptedTerms = true
    home.authFlow.consentedVersion = "2026-09"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = OutdatedTermsAuthUseCase(
        profile: AuthProfile(user: user, currentTermsVersion: "2026-10")
      )
    }
    store.exhaustivity = .off

    await store.send(.view(.submitOnboarding)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.inner.profileUpdated) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = true
      home.authFlow.hasRetriedTermsUpdate = true
      home.authFlow.acceptedTerms = false
      home.authFlow.consentedVersion = nil
      home.authFlow.message = "약관이 변경됐어요. 내용을 확인하고 다시 동의해 주세요."
      home.authFlow.generation = 2
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
      home.authFlow.lastVerifiedUserID = "user-a"
      home.authFlow.nickname = "테스터"
      home.authFlow.message = "변경된 약관을 확인하고 다시 동의해 주세요."
      $0 = .home(home)
    }
  }

  @Test func returningFromTermsLinkPreservesDraftWhenVersionIsUnchanged() async {
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: nil,
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
    let profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
    var home = MainTabCoordinator.State()
    home.authFlow.profile = profile
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.nickname = "작성 중"
    home.authFlow.acceptedTerms = true
    home.authFlow.consentedVersion = "2026-10"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = ReturningProfileAuthUseCase(profile: profile)
    }
    store.exhaustivity = .off

    await store.send(.view(.foregrounded)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.isLoading = true
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.profile = profile
      home.authFlow.verifiedUserID = "user-a"
      home.authFlow.presentation = .onboarding
      $0 = .home(home)
    }
  }

  @Test func secondOutdatedTermsResponseStopsResubmission() async {
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: "테스터",
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 2
    home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
    home.authFlow.presentation = .onboarding
    home.authFlow.isLoading = true
    home.authFlow.hasRetriedTermsUpdate = true
    home.authFlow.acceptedTerms = true
    home.authFlow.consentedVersion = "2026-10"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    }

    await store.send(.inner(.profileUpdated(generation: 2, .failure(.termsOutdated)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.termsUpdateExhausted = true
      home.authFlow.acceptedTerms = false
      home.authFlow.consentedVersion = nil
      home.authFlow.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
      $0 = .home(home)
    }
  }

  @Test func tappingTabSwitchesAndRemembersPreviousTab() async {
    let store = TestStore(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    }
    await store.send(.tabTapped(.timetable))
    await store.receive(\.selectTab) {
      $0.selectedTab = .timetable
      $0.previousTab = .live
    }
    await store.receive(\.timetable.timetableAppeared)
    await store.send(.tabTapped(.timetable))
    await store.receive(\.tabReselected)
  }

  @Test func homeCoordinatorStartsWithFestivalFeatureRoute() {
    let coordinator = FestivalCoordinator.State()
    #expect(coordinator.routes.count == 1)
    #expect(coordinator.routes.first?.screen.festivalList != nil)
  }

  @Test func bottomTabsAppearOnFestivalLiveBoard() {
    var state = MainTabCoordinator.State()
    #expect(state.shouldHideTabBar)

    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    #expect(!state.shouldHideTabBar)

    state.festivalState.routes.goBack()
    #expect(state.shouldHideTabBar)
  }

  @Test func swipingBackFromLiveBoardReturnsToFestivalList() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    let store = TestStore(initialState: state) {
      FestivalCoordinator()
    }

    await store.send(.router(.routeAction(id: 1, action: .liveBoard(.view(.backToFestivalList))))) {
      $0.routes.goBack()
    }
  }

  @Test func openingLiveBoardCarriesVerifiedBookmarkAccount() {
    var list = FestivalFeature.State()
    list.bookedUserID = "user-a"
    var state = FestivalCoordinator.State()
    state.routes = [.root(.festivalList(list), embedInNavigationView: true)]
    _ = FestivalCoordinator().handleRoute(
      state: &state,
      action: .router(.routeAction(id: 0, action: .festivalList(.view(.selectFestival("festival")))))
    )
    #expect(state.routes.last?.screen.liveBoard?.bookedUserID == "user-a")
  }

  @Test func bookmarkReloadSynchronizesListAndLiveBoard() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    let store = TestStore(initialState: state) {
      FestivalCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in userID == "user-a" ? ["festival"] : [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.reloadBookmarks(userID: "user-a"))
    await store.receive(\.router)
    await store.receive(\.router)
    #expect(store.state.routes.first?.screen.festivalList?.bookedUserID == "user-a")
    #expect(store.state.routes.last?.screen.liveBoard?.bookedUserID == "user-a")
    #expect(store.state.routes.first?.screen.festivalList?.bookedFestivalIDs == ["festival"])
    #expect(store.state.routes.last?.screen.liveBoard?.bookedFestivalIDs == ["festival"])
  }

  @Test func completedBookmarkSetsRequestedStateAfterMigration() async {
    let box = BookmarkBox(ids: ["festival"])
    let bookedStore = FestivalBookedStore(
      load: { _ in box.ids },
      save: { ids, _ in box.ids = ids }
    )
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: "테스터",
      nicknameConfirmed: true, termsAcceptedAt: "2026-10-30", termsVersion: "2026-10",
      pushOptIn: false, profileImageURL: nil
    )
    var state = MainTabCoordinator.State()
    state.authFlow.verifiedUserID = user.id
    state.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = bookedStore
    }
    store.exhaustivity = .off

    await store.send(.completePendingBookmark(id: "festival", userID: "user-a", shouldBeBooked: true))
    #expect(box.ids == ["festival"])
    await store.send(.completePendingBookmark(id: "festival", userID: "user-a", shouldBeBooked: false))
    #expect(box.ids.isEmpty)
    await store.send(.completePendingBookmark(id: "festival", userID: "another-user", shouldBeBooked: true))
    #expect(box.ids.isEmpty)
  }

  @Test func timetableUsesSelectedFestivalPackTimes() throws {
    let payload = #"{"id":"festival","stages":[{"id":"main","name":"메인 무대"}],"sets":[{"id":"set-1","artist":"가수","stageId":"main","startsAt":"2026-10-30T12:00:00+09:00","endsAt":"2026-10-30T13:00:00+09:00"}]}"#
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(payload.utf8))

    let days = FestivalPackTimetableMapper.days(from: pack)

    #expect(days.count == 1)
    #expect(days.first?.id == "2026-10-30")
    #expect(days.first?.stages.first?.name == "메인 무대")
    #expect(days.first?.sets.first?.start == 720)
    #expect(days.first?.sets.first?.end == 780)
  }
}

private struct UnauthenticatedAuthUseCase: AuthUseCaseInterface {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    throw AuthDomainError.notAuthenticated
  }

  func fetchProfile() async throws -> AuthProfile {
    throw AuthDomainError.notAuthenticated
  }

  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.notAuthenticated
  }

  func signOut() async throws {}
  func withdraw() async throws {}
}

enum ProfileStubFailure: Sendable {
  case server
  case missingVersion
}

private struct FailingProfileAuthUseCase: AuthUseCaseInterface {
  let failure: ProfileStubFailure
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.invalidResponse }
  func fetchProfile() async throws -> AuthProfile {
    switch failure {
    case .server: throw FestiCoreNetworkError.response(ResponseError(httpStatus: 503))
    case .missingVersion: throw AuthDomainError.invalidResponse
    }
  }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.invalidResponse
  }
  func signOut() async throws {}
  func withdraw() async throws {}
}

private struct ReturningProfileAuthUseCase: AuthUseCaseInterface {
  let profile: AuthProfile
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.invalidResponse }
  func fetchProfile() async throws -> AuthProfile { profile }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.invalidResponse
  }
  func signOut() async throws {}
  func withdraw() async throws {}
}

private struct OutdatedTermsAuthUseCase: AuthUseCaseInterface {
  let profile: AuthProfile
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.invalidResponse }
  func fetchProfile() async throws -> AuthProfile { profile }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw FestiCoreNetworkError.response(ResponseError(
      httpStatus: 422, code: "TERMS_VERSION_OUTDATED"
    ))
  }
  func signOut() async throws {}
  func withdraw() async throws {}
}

private func eligibleProfile(id: String) -> AuthProfile {
  let user = AuthUser(
    id: id, provider: "apple", email: nil, nickname: "테스터",
    nicknameConfirmed: true, termsAcceptedAt: "2026-10-30", termsVersion: "2026-10",
    pushOptIn: false, profileImageURL: nil
  )
  return AuthProfile(user: user, currentTermsVersion: "2026-10")
}

private struct EmptyFestivalCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { [] }
  func refresh() async throws -> [FestivalCatalogItem] { [] }
}

private final class BookmarkBox: @unchecked Sendable {
  private let lock = NSLock()
  private var storedIDs: Set<String>

  init(ids: Set<String>) { storedIDs = ids }

  var ids: Set<String> {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storedIDs
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      storedIDs = newValue
    }
  }
}
