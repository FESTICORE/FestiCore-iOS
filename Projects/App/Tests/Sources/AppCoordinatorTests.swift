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
import FestiCoreAuthInterface
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
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
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
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival")))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.inner.sessionRestored) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      $0 = .home(home)
    }
  }

  @Test func authenticatedBookmarkDoesNotShowLoginDuringSessionRestore() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    }
    store.exhaustivity = .off

    await store.send(.inner(.sessionRestored(generation: 1, userID: "user-a", isLoggedIn: true))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.lastVerifiedUserID = "user-a"
      home.authFlow.hasSession = true
      $0 = .home(home)
    }
    guard case let .home(restored) = store.state else { return }
    #expect(restored.authFlow.presentation == nil)
    #expect(restored.authFlow.pendingFestivalID == "festival")
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

    await store.send(.inner(.sessionRestored(generation: 1, userID: "user-a", isLoggedIn: true)))
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

    await store.send(.inner(.sessionRestored(generation: 1, userID: "user-b", isLoggedIn: true)))
    await store.send(.inner(.profileLoaded(generation: 1, .failure(.offline))))
    guard case let .home(switched) = store.state else { return }
    #expect(switched.authFlow.pendingFestivalID == nil)
    #expect(switched.authFlow.verifiedUserID == "user-b")
    #expect(box.ids == ["saved-a"])

    await store.send(.inner(.sessionRestored(generation: 1, userID: nil, isLoggedIn: false)))
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.authFlow.verifiedUserID == nil)
    #expect(signedOut.authFlow.lastVerifiedUserID == nil)
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
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
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
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
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
      home.authFlow.lastVerifiedUserID = nil
      home.authFlow.profile = nil
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    await store.receive(\.scope.home.festival.accountChanged)
    await store.receive(\.scope.home.flag.accountChanged)
    await store.receive(\.scope.home.festival.router)
    guard case let .home(current) = store.state else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(current.authFlow.pendingFestivalID == "festival")
    #expect(current.authFlow.pendingOwnerID == "user-a")
  }

  @Test func signOutClearsPreviousAccountFlagsLiveBoardAndBookingsImmediately() async {
    await expectAccountDataCleared(by: .inner(.myAccountFinished(
      generation: 1,
      operation: .signOut,
      result: .success(())
    )))
  }

  @Test func profileLoad401ClearsPreviousAccountFlagsLiveBoardAndBookingsImmediately() async {
    await expectAccountDataCleared(by: .inner(.profileLoaded(generation: 1, .failure(.unauthenticated))))
  }

  @Test func profileUpdate401ClearsPreviousAccountFlagsLiveBoardAndBookingsImmediately() async {
    await expectAccountDataCleared(by: .inner(.profileUpdated(generation: 1, .failure(.unauthenticated))))
  }

  private func expectAccountDataCleared(by action: AppCoordinator.Action) async {
    let snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival",
      activeFlags: [],
      followedFlags: [.init(id: "followed", name: "이전 계정 깃발", status: "active", zoneID: "A", activity: nil, thumbnailURL: nil)],
      crew: .init(id: "crew", name: "이전 계정 크루", members: [])
    )
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.liveBoard = snapshot
    board.bookedUserID = "user-a"
    board.bookedFestivalIDs = ["festival"]
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.hasSession = true
    home.flagState = FestivalFlagFeature.State(festivalID: "festival")
    home.flagState.snapshot = snapshot
    home.flagState.viewState = .loaded
    home.festivalState.routes = [.root(.festivalList(board), embedInNavigationView: true)]
    home.festivalState.routes.push(.liveBoard(board))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(action)
    guard case let .home(cleared) = store.state else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(cleared.flagState.snapshot == nil)
    #expect(cleared.flagState.viewState == .idle)
    for route in cleared.festivalState.routes {
      let screen: FestivalFeature.State
      switch route.screen {
      case let .festivalList(state): screen = state
      case let .liveBoard(state): screen = state
      }
      #expect(screen.liveBoard == nil)
      #expect(screen.bookedUserID == nil)
      #expect(screen.bookedFestivalIDs.isEmpty)
    }
    #expect(cleared.festivalState.routes.count == 2)
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
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
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
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
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
    #expect(!state.shouldReserveTabBarSpace)

    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    state.festivalState.routes.goBack()
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)
  }

  @Test func myModalHidesBottomTabsUntilDismissed() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    let store = TestStore(initialState: state) { MainTabCoordinator() }
    await store.send(.profile(.view(.accountTapped(isSignedIn: true)))) {
      $0.profileState.isAccountPresented = true
    }
    #expect(store.state.shouldHideTabBar)
    #expect(store.state.shouldReserveTabBarSpace)
    await store.send(.profile(.view(.accountDismissed))) {
      $0.profileState.isAccountPresented = false
    }
    #expect(!store.state.shouldHideTabBar)
    #expect(store.state.shouldReserveTabBarSpace)

    state.authFlow.presentation = .login
    #expect(state.shouldHideTabBar)
    state.authFlow.presentation = nil
    #expect(!state.shouldHideTabBar)

    state.profileState.isLegalLinkUnavailablePresented = true
    #expect(state.shouldHideTabBar)
    state.profileState.isLegalLinkUnavailablePresented = false
    #expect(!state.shouldHideTabBar)

    state.profileState.isLogoutConfirmationPresented = true
    #expect(state.shouldHideTabBar)
    state.profileState.isLogoutConfirmationPresented = false
    state.profileState.isWithdrawalConfirmationPresented = true
    #expect(state.shouldHideTabBar)
    state.profileState.isWithdrawalConfirmationPresented = false
    #expect(!state.shouldHideTabBar)
  }

  @Test func timetableAndAuthModalsKeepTabBarSpace() {
    var state = MainTabCoordinator.State(selectedTab: .timetable)
    #expect(state.shouldReserveTabBarSpace)
    #expect(!state.shouldHideTabBar)

    state.timetableState.selectedSetID = "set-1"
    #expect(state.shouldReserveTabBarSpace)
    #expect(state.shouldHideTabBar)
    state.timetableState.selectedSetID = nil
    #expect(!state.shouldHideTabBar)

    state.selectedTab = .flag
    state.authFlow.presentation = .login
    #expect(state.shouldReserveTabBarSpace)
    #expect(state.shouldHideTabBar)
    state.authFlow.presentation = nil
    #expect(!state.shouldHideTabBar)

    state.selectedTab = .live
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    state.authFlow.presentation = .onboarding
    #expect(state.shouldReserveTabBarSpace)
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

  @Test func accountChangeReloadsVisiblePushedLiveBoardBehindHiddenList() async {
    let current = FestivalLiveBoardSnapshot(festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil)
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.isLiveBoardVisible = true
    board.hasSession = true
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(board))
    let clock = TestClock()
    let store = TestStore(initialState: state) {
      FestivalCoordinator()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date = .constant(Date(timeIntervalSince1970: 1_000))
      $0.festivalLiveBoardService = FixedLiveBoardService(snapshot: current)
    }
    store.exhaustivity = .off

    await store.send(.accountChanged)
    await store.receive {
      guard case .router(.routeAction(id: 1, action: .liveBoard(.inner(.liveBoardLoaded)))) = $0 else { return false }
      return true
    }
    #expect(store.state.routes.last?.screen.liveBoard?.liveBoard == current)
    await store.send(.router(.routeAction(id: 1, action: .liveBoard(.view(.liveBoardOnDisappear)))))
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

  @Test func openingLiveBoardCarriesSessionFromList() {
    var list = FestivalFeature.State()
    list.hasSession = true
    list.sessionUserID = "user-a"
    list.accountGeneration = 3
    var state = FestivalCoordinator.State()
    state.routes = [.root(.festivalList(list), embedInNavigationView: true)]
    _ = FestivalCoordinator().handleRoute(
      state: &state,
      action: .router(.routeAction(id: 0, action: .festivalList(.view(.selectFestival("festival")))))
    )
    let board = state.routes.last?.screen.liveBoard
    #expect(board?.hasSession == true)
    #expect(board?.sessionUserID == "user-a")
    #expect(board?.accountGeneration == 3)
  }

  @Test func liveBoardLoginCardPresentsLoginSheet() async {
    var home = MainTabCoordinator.State()
    home.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.router(.routeAction(id: 1, action: .liveBoard(.view(.loginTapped))))))))
    await store.receive {
      guard case .scope(.home(.delegate(.myLoginRequested))) = $0 else { return false }
      return true
    }
    guard case let .home(presented) = store.state else { return }
    #expect(presented.authFlow.presentation == .login)
  }

  @Test func restoredSessionWithoutOfflineEligibilityStillReachesLiveBoard() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in }, offlineEligible: { _ in false })
    }
    store.exhaustivity = .off

    await store.send(.inner(.sessionRestored(generation: 1, userID: "user-a", isLoggedIn: true)))
    await store.receive {
      guard case .scope(.home(.festival(.sessionChanged(hasSession: true, userID: "user-a")))) = $0 else { return false }
      return true
    }
    #expect(store.state.festivalSession == .init(hasSession: true, userID: "user-a"))
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

  @Test func flagTabFollowsSelectedFestival() async {
    var state = MainTabCoordinator.State()
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival-a")))
    let store = TestStore(initialState: state) { MainTabCoordinator() }

    await store.send(.tabTapped(.flag))
    await store.receive(\.selectTab) { $0.selectedTab = .flag }
    await store.receive(\.flag.festivalChanged) { $0.flagState.festivalID = "festival-a" }
  }

  @Test func myLogoutClearsVisibleAccountOnlyAfterSuccess() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.hasSession = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.delegate(.myLogoutRequested)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    guard case let .home(loading) = store.state else { return }
    #expect(loading.authFlow.profile?.user.id == "user-a")
    await store.receive(\.inner.myAccountFinished) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      $0 = .home(home)
    }
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.authFlow.profile == nil)
  }

  @Test func completedAccountOperationClosesSheetAfterSwitchingTabs() async {
    var home = MainTabCoordinator.State(selectedTab: .flag)
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.hasSession = true
    home.profileState.isAccountPresented = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.inner(.myAccountFinished(
      generation: 1,
      operation: .signOut,
      result: .success(())
    ))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      home.profileState = .init()
      $0 = .home(home)
    }
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.selectedTab == .flag)
    #expect(!signedOut.profileState.isAccountPresented)
  }

  @Test func myWithdrawalFailureRetainsAccount() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.hasSession = true
    home.profileState.isAccountPresented = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = FailingMyAuthUseCase()
    }

    await store.send(.scope(.home(.delegate(.myWithdrawRequested)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.inner.myAccountFinished) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.accountOperationGeneration = nil
      home.authFlow.isLoading = false
      home.authFlow.message = "회원 탈퇴에 실패했습니다. 다시 시도해 주세요."
      $0 = .home(home)
    }
    guard case let .home(unchanged) = store.state else { return }
    #expect(unchanged.authFlow.profile?.user.id == "user-a")
    #expect(unchanged.profileState.isAccountPresented)
  }

  @Test func unauthenticatedWithdrawalClearsAccount() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.isLoading = true
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.profileState.isAccountPresented = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.inner(.myAccountFinished(
      generation: 1,
      operation: .withdraw,
      result: .failure(.unauthenticated)
    ))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      home.profileState = .init()
      $0 = .home(home)
    }
    guard case let .home(signedOut) = store.state else { return }
    #expect(!signedOut.authFlow.hasSession)
    #expect(signedOut.authFlow.profile == nil)
    #expect(signedOut.authFlow.verifiedUserID == nil)
    #expect(!signedOut.profileState.isAccountPresented)
  }

  @Test func dismissingRetryWhileLoadingAllowsForegroundRefresh() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.presentation = .retry
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.view(.dismissFlow)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.isLoading = false
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.send(.inner(.profileLoaded(generation: 1, .failure(.offline))))
    await store.send(.view(.foregrounded)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 3
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
  }

  @Test func dismissingOnboardingWhileSavingAllowsLogout() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.presentation = .onboarding
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.view(.dismissFlow)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.isLoading = false
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    let previous = eligibleProfile(id: "user-a").user
    await store.send(.inner(.profileUpdated(generation: 1, .success(previous))))
    await store.send(.scope(.home(.delegate(.myLogoutRequested)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 3
      home.authFlow.accountOperationGeneration = 3
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
  }

  @Test func myLogoutWorksWhenSessionHasNoUserIDAndProfileFetchFailed() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.message = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.inner(.sessionRestored(generation: 0, userID: nil, isLoggedIn: true))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.hasSession = true
      $0 = .home(home)
    }

    await store.send(.scope(.home(.delegate(.myLogoutRequested)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      $0 = .home(home)
    }
    await store.receive(\.inner.myAccountFinished) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      $0 = .home(home)
    }
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.authFlow.hasSession == false)
  }

  @Test func bookmarkCannotInvalidatePendingAccountOperation() async {
    var home = MainTabCoordinator.State(selectedTab: .flag)
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.isLoading = true
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival"))))))
    await store.send(.inner(.myAccountFinished(
      generation: 1,
      operation: .signOut,
      result: .success(())
    ))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      $0 = .home(home)
    }
    guard case let .home(signedOut) = store.state else { return }
    #expect(!signedOut.authFlow.hasSession)
    #expect(signedOut.authFlow.profile == nil)
  }

  @Test func bookmarkDuringProfileRefreshStartsNewRequest() async {
    var home = MainTabCoordinator.State(selectedTab: .flag)
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival")))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.pendingFestivalID = "festival"
      $0 = .home(home)
    }
    await store.receive(\.inner.sessionRestored) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    await store.receive(\.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      $0 = .home(home)
    }
  }

  @Test func accountOperationFinishesAfterFlowDismissChangesGeneration() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.isLoading = true
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.presentation = .onboarding
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.view(.dismissFlow)) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.send(.inner(.myAccountFinished(
      generation: 1,
      operation: .withdraw,
      result: .success(())
    ))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 2
      $0 = .home(home)
    }
    guard case let .home(withdrawn) = store.state else { return }
    #expect(!withdrawn.authFlow.hasSession)
    #expect(withdrawn.authFlow.profile == nil)
  }

  @Test func profileUpdateOfflineFailureKeepsAccount() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.hasSession = true
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }

    await store.send(.inner(.profileUpdated(generation: 1, .failure(.offline)))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
      $0 = .home(home)
    }
    guard case let .home(unchanged) = store.state else { return }
    #expect(unchanged.authFlow.profile?.user.id == "user-a")
  }
}

private struct FailingMyAuthUseCase: AuthUseCaseInterface {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.notAuthenticated }
  func fetchProfile() async throws -> AuthProfile { throw AuthDomainError.notAuthenticated }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.notAuthenticated
  }
  func signOut() async throws { throw FestiCoreNetworkError.response(ResponseError(httpStatus: 503)) }
  func withdraw() async throws { throw FestiCoreNetworkError.response(ResponseError(httpStatus: 503)) }
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

private struct StubAuthService: AuthService {
  let loggedIn: Bool
  let userID: String?

  var isLoggedIn: Bool { get async { loggedIn } }
  var currentUserID: String? { get async { userID } }
  var refreshToken: String? {
    get async {
      Issue.record("테스트에서 refreshToken 조회를 예상하지 않았어요")
      return nil
    }
  }

  func signIn(accessToken: String, refreshToken: String) async {
    Issue.record("테스트에서 signIn 호출을 예상하지 않았어요")
  }

  func rememberUserID(_ userID: String) async {
    Issue.record("테스트에서 rememberUserID 호출을 예상하지 않았어요")
  }

  func signOut() async {
    Issue.record("테스트에서 signOut 호출을 예상하지 않았어요")
  }
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

private struct FixedLiveBoardService: FestivalLiveBoardService {
  let snapshot: FestivalLiveBoardSnapshot

  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    snapshot
  }
}
