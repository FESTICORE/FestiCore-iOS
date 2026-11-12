//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Foundation
import Synchronization
import Testing
import UIKit

import ComposableArchitecture
import AuthDomainInterface
import FeatureAssembly
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreStorageInterface
import FestiCoreSharedUI
import FestiCoreUtility
import TCAFlow
import TimetableDomainInterface
@testable import FestiCore

private enum OnboardingTestError: Error {
  case unreadable
  case unwritable
}

@MainActor
struct AppCoordinatorTests {
  @Test func startsAtSplash() {
    #expect(AppCoordinator.State() == .splash(.init()))
  }

  @Test func legalLinksUseConfiguredAPIHost() {
    // 앱 Info.plist의 약관 기준 주소는 xcconfig에서 API 호스트로 조립한다.
    let host = Bundle.main.object(forInfoDictionaryKey: "FestiCoreAPIHost") as? String
    let base = LegalDocumentURL.baseURL
    #expect(host?.isEmpty == false)
    #expect(base?.host() == host)
    #expect(base?.appending(path: "terms").absoluteString
      == "https://\(host ?? "")/api/v1/legal/terms")
    #expect(base?.appending(path: "privacy").absoluteString
      == "https://\(host ?? "")/api/v1/legal/privacy")
  }

  @Test func remoteContentRefreshCompletesBackgroundFetchOnlyOnce() {
    var results: [UIBackgroundFetchResult] = []
    let request = RemoteContentRefreshRequest { results.append($0) }

    request.finish(.newData)
    request.finish(.failed)

    #expect(results == [.newData])
  }

  @Test func loggedOutLaunchShowsLaunchLoginOverHome() async {
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { true }, markCompleted: {}
      )
    }
    store.exhaustivity = .off
    await store.send(.scope(.splash(.delegate(.presentHome))))
    await store.receive(\.view.presentHome)
    await store.receive(\.inner.firstInstallStatus)
    await store.receive(\.inner.sessionChecked) {
      $0 = .home(launchLoginHome())
    }
    // 첫 진입 화면이 떠 있는 동안에는 세션 재확인이 화면을 닫지 않는다.
    await store.receive(\.view.foregrounded)
    #expect(store.state.isLaunchLoginPresented)
  }

  @Test func firstInstallShowsOnboardingThenLaunchLogin() async {
    let saves = Mutex(0)
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { false }, markCompleted: { saves.withLock { $0 += 1 } }
      )
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
    }
    store.exhaustivity = .off
    await store.send(.scope(.splash(.delegate(.presentHome))))
    await store.receive(\.view.presentHome)
    await store.receive(\.inner.firstInstallStatus) {
      $0 = .onboarding(.init())
    }
    await store.send(.scope(.onboarding(.view(.skipTapped))))
    await store.receive(\.scope.onboarding.delegate.completed)
    await store.receive(\.inner.sessionChecked) {
      $0 = .home(launchLoginHome())
    }
    #expect(saves.withLock { $0 } == 1)
  }

  @Test func unreadableInstallReceiptOpensHome() async {
    let store = TestStore(initialState: AppCoordinator.State()) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { throw OnboardingTestError.unreadable }, markCompleted: {}
      )
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
    }
    store.exhaustivity = .off
    await store.send(.scope(.splash(.delegate(.presentHome))))
    await store.receive(\.view.presentHome)
    await store.receive(\.inner.firstInstallStatus)
    await store.receive(\.inner.sessionChecked) { $0 = .home(launchLoginHome()) }
  }

  @Test func failedReceiptWriteOpensHomeButRelaunchShowsOnboarding() async {
    let saves = Mutex(0)
    let first = TestStore(initialState: AppCoordinator.State.onboarding(.init())) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { false },
        markCompleted: {
          saves.withLock { $0 += 1 }
          throw OnboardingTestError.unwritable
        }
      )
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
    }
    first.exhaustivity = .off
    await first.send(.scope(.onboarding(.view(.skipTapped))))
    await first.receive(\.scope.onboarding.delegate.completed)
    await first.receive(\.inner.sessionChecked) { $0 = .home(launchLoginHome()) }
    #expect(saves.withLock { $0 } == 1)

    let relaunched = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { false }, markCompleted: {}
      )
    }
    relaunched.exhaustivity = .off
    await relaunched.send(.scope(.splash(.delegate(.presentHome))))
    await relaunched.receive(\.view.presentHome)
    await relaunched.receive(\.inner.firstInstallStatus) { $0 = .onboarding(.init()) }
  }

  @Test func completingLastOnboardingPageSavesExactlyOnce() async {
    let saves = Mutex(0)
    var onboarding = OnboardingFeature.State()
    onboarding.page = 3
    let store = TestStore(initialState: AppCoordinator.State.onboarding(onboarding)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { false }, markCompleted: { saves.withLock { $0 += 1 } }
      )
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
    }
    store.exhaustivity = .off
    await store.send(.scope(.onboarding(.view(.nextTapped))))
    await store.receive(\.scope.onboarding.delegate.completed)
    await store.receive(\.inner.sessionChecked) { $0 = .home(launchLoginHome()) }
    #expect(saves.withLock { $0 } == 1)
  }

  @Test func repeatedHomeTransitionKeepsExistingState() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
    }
    await store.send(.inner(.completeHomeTransition))
  }

  @Test func loggedInLaunchShowsHomeWithoutLaunchLogin() async {
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-a"))
      $0.authService = StubAuthService(
        loggedIn: true,
        userID: "user-a"
      )
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { true },
        markCompleted: {}
      )
    }
    store.exhaustivity = .off
    await store.send(.scope(.splash(.delegate(.presentHome))))
    await store.receive(\.view.presentHome)
    await store.receive(\.inner.firstInstallStatus)
    await store.receive(\.inner.sessionChecked) {
      $0 = .home(.init())
    }
    await store.receive(\.scope.home.session.inner.profileLoaded)
    #expect(!store.state.isLaunchLoginPresented)
    guard case let .home(home) = store.state else { return }
    #expect(home.authFlow.hasSession)
  }

  @Test func skippingLaunchLoginOpensHomeOnlyForThisLaunch() async {
    let store = TestStore(initialState: AppCoordinator.State.home(launchLoginHome())) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(
        loggedIn: false,
        userID: nil
      )
    }
    store.exhaustivity = .off
    // 건너뛰기는 로그인 시트의 닫기와 같은 경로로 첫 진입 화면을 닫고, 홈에서 세션을 확인한다.
    await store.send(.scope(.home(.auth(.login(.view(.closeTapped))))))
    await store.receive(\.scope.home.auth.login.delegate.closeRequested) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.presentation = nil
      home.authFlow.generation = 1
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.view.foregrounded)
    await store.receive(\.view.deeplinkReceived)
    await store.receive(\.scope.home.session.inner.profileLoaded)
    #expect(!store.state.isLaunchLoginPresented)

    // 건너뛰기를 저장하지 않으므로 다음 실행에서도 로그아웃 상태면 다시 첫 진입 화면이 뜬다.
    let relaunched = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(
        loggedIn: false,
        userID: nil
      )
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
      $0.firstInstallOnboardingStore = FirstInstallOnboardingStore(
        hasCompleted: { true },
        markCompleted: {}
      )
    }
    relaunched.exhaustivity = .off
    await relaunched.send(.scope(.splash(.delegate(.presentHome))))
    await relaunched.receive(\.view.presentHome)
    await relaunched.receive(\.inner.firstInstallStatus)
    await relaunched.receive(\.inner.sessionChecked) {
      $0 = .home(launchLoginHome())
    }
  }

  @Test func launchLoginSuccessClosesScreenAndOpensSignUpForNewAccount() async {
    let newUser = AuthUser(
      id: "user-a",
      provider: "apple",
      email: nil,
      nickname: nil,
      nicknameConfirmed: false,
      termsAcceptedAt: nil,
      termsVersion: nil,
      pushOptIn: false,
      profileImageURL: nil
    )
    let store = TestStore(initialState: AppCoordinator.State.home(launchLoginHome())) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.analyticsUseCase = .recording()
      $0.oauthUseCase = SucceedingOAuthUseCase(result: AuthLoginResult(
        newUser: true,
        user: newUser
      ))
      $0.authUseCase = ReturningProfileAuthUseCase(profile: AuthProfile(
        user: newUser,
        currentTermsVersion: "2026-10"
      ))
      $0.authService = StubAuthService(
        loggedIn: true,
        userID: "user-a"
      )
    }
    store.exhaustivity = .off
    // 첫 진입 화면의 Apple 버튼은 로그인 시트와 같은 OAuth 경로를 탄다.
    await store.send(.scope(.home(.auth(.login(.view(.signInTapped(.apple)))))))
    await store.receive(\.scope.home.auth.login.delegate.signInRequested)
    await store.receive(\.scope.home.auth.login.delegate.signedIn)
    #expect(!store.state.isLaunchLoginPresented)
    await store.receive(\.scope.home.session.inner.profileLoaded)
    guard case let .home(home) = store.state else { return }
    // 가입이 필요한 계정이면 기존 가입 시트(S14 B)로 이어진다.
    #expect(home.authFlow.hasSession)
    #expect(home.authFlow.presentation == .onboarding)
  }

  @Test func launchLoginFailureKeepsScreen() async {
    let store = TestStore(initialState: AppCoordinator.State.home(launchLoginHome())) {
      AppCoordinator()
    } withDependencies: {
      $0.oauthUseCase = CancelledOAuthUseCase()
    }
    store.exhaustivity = .off
    await store.send(.scope(.home(.auth(.login(.view(.signInTapped(.google)))))))
    await store.receive(\.scope.home.auth.login.inner.signInFailed)
    #expect(store.state.isLaunchLoginPresented)
  }

  @Test func pendingDeeplinkOpensAfterLaunchLoginCloses() async {
    let storage = InMemoryStorage()
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.defaultInMemoryStorage = storage
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(
        loggedIn: false,
        userID: nil
      )
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { AsyncStream { $0.finish() } })
    }
    store.exhaustivity = .off
    withDependencies {
      $0.defaultInMemoryStorage = storage
    } operation: {
      PendingDeeplinkStore().save(.festivalList)
    }
    await store.send(.inner(.sessionChecked(isLoggedIn: false))) {
      $0 = .home(launchLoginHome())
    }
    // 첫 진입 화면이 떠 있으면 대기 딥링크를 꺼내지 않는다.
    await store.receive(\.view.deeplinkReceived)
    #expect(store.state.isLaunchLoginPresented)
    await store.send(.scope(.home(.auth(.login(.view(.closeTapped))))))
    await store.receive(\.scope.home.auth.login.delegate.closeRequested)
    await store.receive(\.view.deeplinkReceived)
    await store.receive(
      \.view.openDeeplink,
      .festivalList
    )
    await store.receive(\.scope.home.openDeeplink)
  }

  @Test func unauthenticatedBookmarkOpensLoginBeforeProfileFetch() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival"))))))
    await store.receive(\.scope.home.session.view.bookmarkRequested) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.sessionRestored) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      $0 = .home(home)
    }
    // 처음부터 로그인하지 않은 사용자의 예약은 요청 계정이 없어도 유지하고 로그인 시트를 남긴다.
    guard case let .home(guest) = store.state else {
      Issue.record("홈 상태가 아님")
      return
    }
    #expect(guest.authFlow.presentation == .login)
    #expect(guest.authFlow.pendingFestivalID == "festival")
  }

  @Test func authenticatedBookmarkDoesNotShowLoginDuringSessionRestore() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: "user-a",
      isLoggedIn: true
    )))))) {
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
    let clock = TestClock()
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.pendingFestivalID = "new"
    home.authFlow.pendingOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.continuousClock = clock
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in userID == "user-a" ? box.ids : [] },
        save: { ids, userID in if userID == "user-a" { box.ids = ids } },
        offlineEligible: { $0 == "user-a" }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: "user-a",
      isLoggedIn: true
    ))))))
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.offline)
    ))))))
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in userID == "user-a" ? box.ids : ["saved-b"] },
        save: { ids, userID in if userID == "user-a" { box.ids = ids } },
        offlineEligible: { _ in true }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: "user-b",
      isLoggedIn: true
    ))))))
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.offline)
    ))))))
    guard case let .home(switched) = store.state else { return }
    #expect(switched.authFlow.pendingFestivalID == nil)
    #expect(switched.authFlow.verifiedUserID == "user-b")
    #expect(box.ids == ["saved-a"])

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: nil,
      isLoggedIn: false
    ))))))
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.authFlow.verifiedUserID == nil)
    #expect(signedOut.authFlow.lastVerifiedUserID == nil)
    #expect(box.ids == ["saved-a"])
  }

  @Test func foregroundSendsSessionBeforeFestival() async {
    let profile = eligibleProfile(id: "user-a")
    var home = MainTabCoordinator.State()
    home.authFlow.profile = profile
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    // 루트가 보낸 포그라운드 뒤에 받은 액션을 받은 순서대로 기록한다.
    let received = LockIsolated<[String]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      CombineReducers {
        AppCoordinator()
        Reduce<AppCoordinator.State, AppCoordinator.Action> { _, action in
          if action.is(\.view.foregrounded) { return .none }
          let label: String
          if action.is(\.scope.home.session.view.foregrounded) {
            label = "session.foregrounded"
          } else if action.is(\.scope.home.festival) {
            label = "festival"
          } else {
            label = "other"
          }
          received.withValue { $0.append(label) }
          return .none
        }
      }
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: profile)
      $0.authService = StubAuthService(
        loggedIn: true,
        userID: "user-a"
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.view(.foregrounded))
    await store.receive(\.scope.home.session.view.foregrounded)
    await store.receive(\.scope.home.festival)
    await store.finish()

    // 세션이 먼저 확인한 계정을 비워야 축제 화면이 이전 계정으로 다시 읽지 않는다.
    let labels = received.value
    #expect(labels.first == "session.foregrounded")
    let festivalIndex = labels.firstIndex(of: "festival")
    #expect(festivalIndex != nil)
    #expect((festivalIndex ?? 0) > 0)
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = FailingProfileAuthUseCase(failure: failure)
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in box.ids },
        save: { ids, _ in box.ids = ids }
      )
    }
    store.exhaustivity = .off

    await store.send(.view(.foregrounded))
    await store.receive(\.scope.home.session.view.foregrounded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.isLoading = true
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.message = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival"))))))
    await store.receive(\.scope.home.session.view.bookmarkRequested) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.pendingOwnerID = "user-a"
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-b"))
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in box.ids },
        save: { ids, _ in box.ids = ids }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival"))))))
    await store.receive(\.scope.home.session.view.bookmarkRequested) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.pendingOwnerID = "user-a"
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in box.ids },
        save: { ids, _ in box.ids = ids }
      )
    }

    await store.send(.scope(.home(.auth(.view(.dismissFlow))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.pendingFestivalID = nil
      home.authFlow.generation = 2
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    let result = AuthLoginResult(newUser: false, user: eligibleProfile(id: "user-a").user)
    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(result)))))))
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
    // 온보딩의 프로필 수정은 로그인 성공 뒤에만 열리므로 세션이 있는 상태다.
    home.authFlow.hasSession = true
    home.authFlow.presentation = .onboarding
    home.authFlow.isLoading = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .failure(.notAuthenticated)
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.hasSession = false
      home.authFlow.isLoading = false
      home.authFlow.verifiedUserID = nil
      home.authFlow.lastVerifiedUserID = nil
      home.authFlow.profile = nil
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    await store.receive(\.scope.home.festival.accountChanged)
    await store.receive {
      guard case .scope(.home(.festival(.router(.routeAction(id: 0, action: .festivalList(.view(.accountChanged))))))) = $0 else {
        return false
      }
      return true
    }
    await store.receive({ $0.homeFlagDirectoryAction == .accountChanged }) {
      guard case var .home(home) = $0 else { return }
      home.flagState.generation = 1
      $0 = .home(home)
    }
    guard case let .home(current) = store.state else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(current.authFlow.pendingFestivalID == "festival")
    #expect(current.authFlow.pendingOwnerID == "user-a")
  }

  @Test func signOutClearsPreviousAccountFlagsLiveBoardAndBookingsImmediately() async {
    await expectAccountDataCleared(by: .scope(.home(.account(.inner(.finished(
      generation: 1,
      operation: .signOut,
      result: .success(())
    ))))))
  }

  @Test func profileLoad401ClearsPreviousAccountFlagsLiveBoardAndBookingsImmediately() async {
    await expectAccountDataCleared(by: .scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.notAuthenticated)
    ))))))
  }

  @Test func profileUpdate401ClearsPreviousAccountFlagsLiveBoardAndBookingsImmediately() async {
    await expectAccountDataCleared(by: .scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .failure(.notAuthenticated)
    ))))))
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
    home.timetableState.mySetIDs = ["set-a"]
    home.festivalState.routes = [.root(.festivalList(board), embedInNavigationView: true)]
    home.festivalState.routes.push(.liveBoard(board))
    let bookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })

    // 실제 Store는 `Effect.send`를 같은 send 호출 안에서 처리하므로, 부모 액션 직후 이전 계정 깃발이 남지 않는다.
    let liveStore = Store(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = bookedStore
    }
    liveStore.send(action)
    let immediate = liveStore.withState { $0 }
    guard case let .home(immediateHome) = immediate else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(immediateHome.flagState.snapshot == nil)
    #expect(immediateHome.flagState.viewState == .idle)
    #expect(immediateHome.timetableState.mySetIDs.isEmpty)

    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = bookedStore
    }
    store.exhaustivity = .off

    await store.send(action)
    guard case let .home(cleared) = store.state else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    await store.receive { $0.homeFlagDirectoryAction == .accountChanged }
    guard case let .home(flagCleared) = store.state else { return }
    #expect(flagCleared.flagState.snapshot == nil)
    #expect(flagCleared.flagState.viewState == .idle)
    await store.receive(\.scope.home.timetable.view.accountChanged)
    await store.receive(\.scope.home.timetableCoordinator.timetable)
    guard case let .home(scheduleCleared) = store.state else { return }
    #expect(scheduleCleared.timetableState.mySetIDs.isEmpty)
    for route in cleared.festivalState.routes {
      let screen: FestivalFeature.State
      switch route.screen {
      case let .festivalList(state): screen = state
      case let .liveBoard(state): screen = state
      case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist:
        Issue.record("계정 정리 뒤에는 기수 보드나 알림함, 존 지도, 크루 화면이 남지 않아야 한다")
        continue
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
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .failure(.offline)
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
      $0 = .home(home)
    }
    // 가입 시트가 떠 있으므로 바뀐 흐름 문구를 가입 화면에 알린다.
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.auth.signUp.view.flowChanged)
    await store.receive(\.scope.home.auth.signUp.router) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.signUp.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged) { syncProfileAccount(&$0) }
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
    home.authFlow.signUp = SignUpFeature.State()
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.generation = 1
    home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-09")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.signUp.nickname = "테스터"
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.acceptedPrivacyTerms = true
    home.authFlow.signUp.termsDraftVersion = "2026-09"
    home.authFlow.signUp.draftOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = OutdatedTermsAuthUseCase(
        profile: AuthProfile(user: user, currentTermsVersion: "2026-10")
      )
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.signUp(.view(.submitTapped))))))
    await store.receive(\.scope.home.auth.signUp.router)
    await store.receive {
      guard case .scope(.home(.auth(.signUp(.router(.routeAction(
        id: _,
        action: .signUp(.delegate(.submitRequested))
      )))))) = $0 else { return false }
      return true
    } assert: {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.view.signUpSubmitted) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = true
      home.authFlow.hasRetriedTermsUpdate = true
      home.authFlow.signUp.acceptedServiceTerms = false
      home.authFlow.signUp.acceptedPrivacyTerms = false
      home.authFlow.signUp.termsDraftVersion = nil
      home.authFlow.message = "약관이 변경됐어요. 내용을 확인하고 다시 동의해 주세요."
      home.authFlow.generation = 2
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
      home.authFlow.lastVerifiedUserID = "user-a"
      home.authFlow.signUp.nickname = "테스터"
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
    home.authFlow.signUp.nickname = "작성 중"
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.acceptedPrivacyTerms = true
    home.authFlow.signUp.termsDraftVersion = "2026-10"
    home.authFlow.signUp.draftOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: profile)
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
    }
    store.exhaustivity = .off

    await store.send(.view(.foregrounded))
    await store.receive(\.scope.home.session.view.foregrounded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.isLoading = true
      home.authFlow.profile = nil
      home.authFlow.verifiedUserID = nil
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.profile = profile
      home.authFlow.verifiedUserID = "user-a"
      home.authFlow.presentation = .onboarding
      $0 = .home(home)
    }
    guard case let .home(refreshed) = store.state else { return }
    #expect(refreshed.authFlow.signUp.nickname == "작성 중")
    #expect(refreshed.authFlow.signUp.acceptedTerms)
    #expect(refreshed.authFlow.signUp.acceptedServiceTerms && refreshed.authFlow.signUp.acceptedPrivacyTerms)
  }

  @Test func requiredTermsCountOnlyWhenBothRowsAreChecked() async {
    var home = MainTabCoordinator.State()
    home.authFlow.profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    home.authFlow.presentation = .onboarding
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.signUp(.view(.serviceTermsChanged(true)))))))
    await store.receive(\.scope.home.auth.signUp.router)
    guard case let .home(one) = store.state else { return }
    #expect(!one.authFlow.signUp.acceptedTerms)
    #expect(one.authFlow.signUp.consentedVersion == nil)
    #expect(one.authFlow.signUp.draftOwnerID == "user-a")

    await store.send(.scope(.home(.auth(.signUp(.view(.privacyTermsChanged(true)))))))
    await store.receive(\.scope.home.auth.signUp.router)
    guard case let .home(both) = store.state else { return }
    #expect(both.authFlow.signUp.acceptedTerms)
    #expect(both.authFlow.signUp.consentedVersion == "2026-10")
    // 시안 S14-2는 필수 약관 2개만 받으므로 둘 다 켜지면 전체 동의다.
    #expect(both.authFlow.signUp.isAllConsented)

    await store.send(.scope(.home(.auth(.signUp(.view(.allConsentToggled))))))
    await store.receive(\.scope.home.auth.signUp.router)
    guard case let .home(none) = store.state else { return }
    #expect(!none.authFlow.signUp.acceptedServiceTerms && !none.authFlow.signUp.acceptedPrivacyTerms)
    #expect(!none.authFlow.signUp.acceptedTerms)
    #expect(none.authFlow.signUp.consentedVersion == nil)
  }

  @Test func draftFromAnotherAccountIsClearedWhenProfileLoads() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.signUp.nickname = "A의 초안"
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.draftOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    let profile = AuthProfile(user: signUpUser("user-b"), currentTermsVersion: "2026-10")
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .success(profile)
    ))))))
    guard case let .home(loaded) = store.state else { return }
    #expect(loaded.authFlow.signUp.nickname.isEmpty)
    #expect(!loaded.authFlow.signUp.acceptedServiceTerms)
    #expect(loaded.authFlow.signUp.draftOwnerID == nil)
  }

  @Test func accountSwitchDropsPreviousRetryStateAndMessage() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    home.authFlow.presentation = .onboarding
    home.authFlow.signUp.nickname = "A의 초안"
    home.authFlow.signUp.draftOwnerID = "user-a"
    home.authFlow.hasRetriedTermsUpdate = true
    home.authFlow.termsUpdateExhausted = true
    home.authFlow.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .success(signUpUser("user-b"))
    ))))))
    guard case let .home(after) = store.state else { return }
    #expect(after.authFlow.signUp.nickname.isEmpty)
    #expect(!after.authFlow.hasRetriedTermsUpdate)
    #expect(!after.authFlow.termsUpdateExhausted)
    #expect(after.authFlow.message == nil)
  }

  @Test func unownedDraftIsClearedWhenProfileLoads() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.signUp.nickname = "주인 없음"
    home.authFlow.signUp.acceptedPrivacyTerms = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    let profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .success(profile)
    ))))))
    guard case let .home(loaded) = store.state else { return }
    #expect(loaded.authFlow.signUp.nickname.isEmpty)
    #expect(!loaded.authFlow.signUp.acceptedPrivacyTerms)
  }

  @Test func termsVersionChangeClearsBothRequiredRows() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.acceptedPrivacyTerms = true
    home.authFlow.signUp.termsDraftVersion = "2026-10"
    home.authFlow.signUp.draftOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    let profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-11")
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .success(profile)
    ))))))
    guard case let .home(loaded) = store.state else { return }
    #expect(!loaded.authFlow.signUp.acceptedServiceTerms && !loaded.authFlow.signUp.acceptedPrivacyTerms)
    #expect(!loaded.authFlow.signUp.acceptedTerms)
    #expect(loaded.authFlow.signUp.consentedVersion == nil)
  }

  @Test func partialCheckFromOldVersionIsClearedAfterRefreshWithoutProfile() async {
    var home = MainTabCoordinator.State()
    home.authFlow.profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    home.authFlow.presentation = .onboarding
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.signUp(.view(.serviceTermsChanged(true)))))))
    await store.receive(\.scope.home.auth.signUp.router)
    // 포그라운드 갱신처럼 프로필을 비운 뒤 새 약관 버전 프로필을 받는다.
    store.exhaustivity = .off
    guard case var .home(refreshing) = store.state else { return }
    refreshing.authFlow.profile = nil
    refreshing.authFlow.generation = 1
    let refreshed = TestStore(initialState: AppCoordinator.State.home(refreshing)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    refreshed.exhaustivity = .off
    let newProfile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-11")
    await refreshed.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .success(newProfile)
    ))))))
    await refreshed.send(.scope(.home(.auth(.signUp(.view(.privacyTermsChanged(true)))))))
    await refreshed.receive(\.scope.home.auth.signUp.router)
    guard case let .home(after) = refreshed.state else { return }
    #expect(!after.authFlow.signUp.acceptedServiceTerms)
    #expect(!after.authFlow.signUp.acceptedTerms)
    #expect(after.authFlow.signUp.consentedVersion == nil)
  }

  @Test func clearedNicknameIsNotRefilledFromSameAccountProfile() async {
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: "서버 닉네임",
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.profile = AuthProfile(user: user, currentTermsVersion: "2026-10")
    home.authFlow.presentation = .onboarding
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.signUp(.view(.nicknameChanged("")))))))
    await store.receive(\.scope.home.auth.signUp.router)
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .success(AuthProfile(
        user: user,
        currentTermsVersion: "2026-10"
      ))
    ))))))
    guard case let .home(loaded) = store.state else { return }
    #expect(loaded.authFlow.signUp.nickname.isEmpty)
  }

  @Test func clearedNicknameDraftFromAnotherAccountLetsNewAccountUseServerNickname() async {
    let userB = AuthUser(
      id: "user-b", provider: "apple", email: nil, nickname: "B 닉네임",
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.signUp.nicknameEdited = true
    home.authFlow.signUp.draftOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .success(AuthProfile(
        user: userB,
        currentTermsVersion: "2026-10"
      ))
    ))))))
    guard case let .home(loaded) = store.state else { return }
    #expect(loaded.authFlow.signUp.nickname == "B 닉네임")
    #expect(loaded.authFlow.signUp.draftOwnerID == "user-b")
  }

  @Test func unauthenticatedProfileResultsDropPendingBookmarkWithoutKnownOwner() async {
    for result in [
      AppCoordinator.Action.scope(.home(.session(.inner(.profileLoaded(
        generation: 1,
        .failure(.notAuthenticated)
      ))))),
      .scope(.home(.session(.view(.signUpSubmitted(
        generation: 1,
        .failure(.notAuthenticated)
      )))))
    ] {
      var home = MainTabCoordinator.State()
      home.authFlow.generation = 1
      home.authFlow.hasSession = true
      home.authFlow.profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
      home.authFlow.pendingFestivalID = "festival"
      home.authFlow.pendingShouldBeBooked = true
      let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
      store.exhaustivity = .off

      await store.send(result)
      guard case let .home(after) = store.state else { return }
      #expect(after.authFlow.pendingFestivalID == nil)
      #expect(!after.authFlow.pendingShouldBeBooked)
    }
  }

  @Test func unauthenticatedProfileLoadKeepsPendingBookmarkWithKnownOwner() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.hasSession = true
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.notAuthenticated)
    ))))))
    guard case let .home(after) = store.state else { return }
    #expect(after.authFlow.pendingFestivalID == "festival")
    #expect(after.authFlow.presentation == .login)
  }

  @Test func unauthenticatedProfileUpdateClearsSignUpDraft() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.hasSession = true
    home.authFlow.profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    home.authFlow.presentation = .onboarding
    home.authFlow.signUp.nickname = "A의 초안"
    home.authFlow.signUp.nicknameEdited = true
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.acceptedPrivacyTerms = true
    home.authFlow.signUp.termsDraftVersion = "2026-10"
    home.authFlow.signUp.draftOwnerID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .failure(.notAuthenticated)
    ))))))
    guard case let .home(after) = store.state else { return }
    #expect(after.authFlow.signUp.nickname.isEmpty)
    #expect(!after.authFlow.signUp.nicknameEdited)
    #expect(!after.authFlow.signUp.acceptedTerms && !after.authFlow.signUp.acceptedServiceTerms && !after.authFlow.signUp.acceptedPrivacyTerms)
    #expect(after.authFlow.signUp.draftOwnerID == nil)
  }

  private func signUpUser(_ id: String) -> AuthUser {
    AuthUser(
      id: id, provider: "apple", email: nil, nickname: nil,
      nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
      pushOptIn: false, profileImageURL: nil
    )
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
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.acceptedPrivacyTerms = true
    home.authFlow.signUp.termsDraftVersion = "2026-10"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 2,
      .failure(.termsVersionOutdated)
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.termsUpdateExhausted = true
      home.authFlow.signUp.acceptedServiceTerms = false
      home.authFlow.signUp.acceptedPrivacyTerms = false
      home.authFlow.signUp.termsDraftVersion = nil
      home.authFlow.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.auth.signUp.view.flowChanged)
    await store.receive(\.scope.home.auth.signUp.router) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.signUp.termsUpdateExhausted = true
      home.authFlow.signUp.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged) { syncProfileAccount(&$0) }
  }

  @Test func tappingTabSwitchesAndRemembersPreviousTab() async {
    let store = TestStore(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    await store.send(.tabTapped(.timetable))
    await store.receive(\.selectTab) {
      $0.selectedTab = .timetable
      $0.previousTab = .live
      $0.timetableState.contentStatus = .noFestival
    }
    await store.receive(\.timetable.view.timetableAppeared)
    await store.receive(\.timetableCoordinator.timetable)
    await store.send(.tabTapped(.timetable))
    await store.receive(\.tabReselected)
  }

  @Test func returningToFestivalTabReloadsPackCache() async {
    let store = TestStore(initialState: MainTabCoordinator.State(selectedTab: .my)) {
      MainTabCoordinator()
    } withDependencies: {
      $0.festivalPackUseCase = MockFestivalPackUseCase(cachedPacks: { [] })
      $0.festivalImageUseCase = MockFestivalImageUseCase(
        imageURL: { _ in nil }, startPrefetch: { _ in }, stopPrefetch: {}
      )
    }
    store.exhaustivity = .off

    await store.send(.selectTab(.live)) {
      $0.selectedTab = .live
      $0.previousTab = .my
    }
    await store.receive(\.festival.reloadCachedPacks)
    await store.finish()
  }

  @Test func deletingPackInProfileReloadsFestivalList() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.packs = [FestivalReceivedPack(id: "festival", name: "축제", packVersion: 1)]
    state.profileState.destination = .packDetail(.init(festivalID: "festival", title: "축제"))
    let store = TestStore(initialState: state) { MainTabCoordinator() } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { [] }, refreshReceivedPacks: { [] }
      )
      $0.festivalPackUseCase = MockFestivalPackUseCase(cachedPacks: { [] })
      $0.festivalImageUseCase = MockFestivalImageUseCase(
        imageURL: { _ in nil }, startPrefetch: { _ in }, stopPrefetch: {}
      )
    }
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.profile(.destination(.presented(.packDetail(.delegate(.packDeleted))))))) {
      $0.profileState.destination = nil
    }
    await store.receive(\.festival.reloadCachedPacks)
    await store.finish()
  }

  @Test func packDetailHidesBottomTabsWithOrWithoutConfirmation() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    var packDetail = PackDetailFeature.State(
      festivalID: "festival",
      title: "축제"
    )

    for confirmation in [
      nil,
      FCAlertState<FCAlertAction>.alert(title: "새 팩을 받을까요?"),
      .deletePack(name: "축제")
    ] {
      packDetail.destination = confirmation.map { .alert($0) }
      state.profileState.destination = .packDetail(packDetail)
      // 팩 상세는 마지막 카드까지 스크롤되도록 탭바 없이 표시하고, 확인 팝업이 떠도 그대로 숨긴다.
      #expect(state.shouldHideTabBar)
      #expect(!state.shouldReserveTabBarSpace)
    }
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

  @Test func festivalSwitcherHidesBottomTabsAndRestoresThemAfterDismissal() async {
    var state = MainTabCoordinator.State()
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    #expect(!store.state.shouldHideTabBar)
    #expect(store.state.shouldReserveTabBarSpace)
    await store.send(.festival(.router(.routeAction(
      id: 1,
      action: .liveBoard(.view(.festivalSwitchTapped))
    )))) {
      var board = FestivalFeature.State(selectedFestivalID: "festival")
      board.festivalSwitcher = .init(
        festivals: [],
        selectedFestivalID: "festival"
      )
      $0.festivalState.routes[1].screen = .liveBoard(board)
    }
    #expect(store.state.shouldHideTabBar)
    // 시트 전후에 배경 화면 높이가 변하지 않도록 탭바 공간은 보존한다.
    #expect(store.state.shouldReserveTabBarSpace)

    await store.send(.festival(.router(.routeAction(
      id: 1,
      action: .liveBoard(.festivalSwitcher(.dismiss))
    )))) {
      $0.festivalState.routes[1].screen = .liveBoard(.init(selectedFestivalID: "festival"))
    }
    #expect(!store.state.shouldHideTabBar)
    #expect(store.state.shouldReserveTabBarSpace)
  }

  @Test func festivalSwitcherDoesNotHideOtherTabs() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.festivalSwitcher = .init(
      festivals: [],
      selectedFestivalID: "festival"
    )
    state.festivalState.routes.push(.liveBoard(board))

    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)
  }

  @Test func myModalHidesBottomTabsUntilDismissed() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    let store = TestStore(initialState: state) { MainTabCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    await store.send(.profileCoordinator(.profile(.view(.accountChanged(
      profile: nil,
      hasSession: true,
      isLoading: false,
      message: nil
    ))))) {
      $0.profileState.hasSession = true
    }
    // 설정 홈과 그 아래 계정 화면은 다른 마이 설정 화면처럼 탭바 없이 표시한다.
    await store.send(.profileCoordinator(.profile(.view(.settingsTapped)))) {
      $0.profileState.destination = .settings(.init(hasSession: true))
    }
    #expect(store.state.shouldHideTabBar)
    #expect(!store.state.shouldReserveTabBarSpace)
    await store.send(.profileCoordinator(.profile(.destination(.presented(.settings(.view(.accountTapped))))))) {
      $0.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    }
    #expect(store.state.shouldHideTabBar)
    #expect(!store.state.shouldReserveTabBarSpace)
    await store.send(.profileCoordinator(.profile(.destination(.presented(.settings(.destination(.presented(
      .account(.view(.logoutTapped))
    )))))))) {
      $0.profileState.destination = .settings(settingsWithAccount({
        var account = AccountSettingsFeature.State(profile: nil)
        account.destination = .alert(.logout())
        account.confirmation = .logout
        return account
      }()))
    }
    #expect(store.state.shouldHideTabBar)
    await store.send(.profileCoordinator(.profile(.destination(.presented(.settings(.destination(.presented(
      .account(.destination(.presented(.alert(.cancelTapped))))
    )))))))) {
      $0.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    }
    // 팝업을 닫아도 계정 화면에 머무는 동안은 탭바를 숨긴다.
    #expect(store.state.shouldHideTabBar)

    state.authFlow.presentation = .login
    #expect(state.shouldHideTabBar)
    state.authFlow.presentation = nil
    #expect(!state.shouldHideTabBar)

    for alert in [FCAlertState<FCAlertAction>.legalLinkUnavailable(), .logout(), .withdraw()] {
      state.profileState.destination = .alert(alert)
      #expect(state.shouldHideTabBar)
      state.profileState.destination = nil
      #expect(!state.shouldHideTabBar)
    }
  }

  @Test func myPushedLegalLockScreenAndNoticeHideBottomTabs() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    let children: [SettingsHomeFeature.Destination.State] = [
      .legalDocument(.init(
        url: URL(string: "https://example.com/api/v1/legal/terms")!,
        title: "이용약관"
      )),
      .lockScreen(.init()),
      .noticeList(.init()),
    ]
    for child in children {
      var settings = SettingsHomeFeature.State()
      settings.destination = child
      state.profileState.destination = .settings(settings)
      #expect(state.shouldHideTabBar)
      #expect(!state.shouldReserveTabBarSpace)
    }
    state.profileState.destination = nil
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)
  }

  @Test func changedNicknameUpdatesSessionDisplayName() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }
    store.exhaustivity = .off
    let previous = eligibleProfile(id: "user-a").user
    let renamed = AuthUser(
      id: "user-a", provider: previous.provider, email: previous.email, nickname: "새이름",
      nicknameConfirmed: true, termsAcceptedAt: previous.termsAcceptedAt, termsVersion: previous.termsVersion,
      pushOptIn: previous.pushOptIn, profileImageURL: nil
    )
    let other = AuthUser(
      id: "user-b", provider: previous.provider, email: nil, nickname: "다른계정",
      nicknameConfirmed: true, termsAcceptedAt: previous.termsAcceptedAt, termsVersion: previous.termsVersion,
      pushOptIn: false, profileImageURL: nil
    )

    // 다른 계정의 결과는 받지 않는다.
    await store.send(.scope(.home(.session(.view(.profileUpdated(other))))))
    await store.send(.scope(.home(.session(.view(.profileUpdated(renamed))))))
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged)
    guard case let .home(updated) = store.state else {
      Issue.record("홈 상태가 아니다")
      return
    }
    #expect(updated.authFlow.profile?.user.nickname == "새이름")
    #expect(updated.profileState.profile?.user.nickname == "새이름")
  }

  @Test func accountChangesReachProfileAsInputAction() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    // 마이 화면 상태는 앱이 보낸 입력 액션으로만 바뀐다.
    await store.send(.scope(.home(.session(.view(.sessionExpired)))))
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged)
    guard case let .home(updated) = store.state else {
      Issue.record("홈 상태가 아니다")
      return
    }
    #expect(!updated.profileState.hasSession)
    #expect(updated.profileState.destination == nil)
  }

  @Test func timetableAndAuthModalsKeepTabBarSpace() {
    var state = MainTabCoordinator.State(selectedTab: .timetable)
    #expect(state.shouldReserveTabBarSpace)
    #expect(!state.shouldHideTabBar)

    state.timetableState.setDetail = TimetableSetDetailFeature.State(
      setID: "set-1",
      content: .init(
        detail: TimetableSetDetail(artist: "라임", stage: "리벳 스테이지", time: "17:00–17:50 · 50분", status: .live, isScheduled: false),
        interval: DateInterval(start: .distantPast, duration: 50 * 60),
        source: "",
        isScheduleLoading: false,
        isScheduleLimitReached: false
      )
    )
    #expect(state.shouldReserveTabBarSpace)
    #expect(state.shouldHideTabBar)
    state.timetableState.setDetail = nil
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
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
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
      $0.useAppCoordinatorFestivalUseCases()
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

  @Test func openingLiveBoardCarriesUncachedSelectedFestivalFromLaterPage() {
    let items = (1...11).map { FestivalCatalogItem(
      id: "fst_\($0)",
      name: "축제 \($0)",
      packVersion: 0
    ) }
    for selected in [items[1], items[10]] {
      var list = FestivalFeature.State()
      list.catalog = .init(uniqueElements: items)
      var state = FestivalCoordinator.State()
      state.routes = [.root(
        .festivalList(list),
        embedInNavigationView: true
      )]
      _ = FestivalCoordinator().handleRoute(
        state: &state,
        action: .router(.routeAction(
          id: 0,
          action: .festivalList(.view(.selectFestival(selected.id)))
        ))
      )
      let board = state.routes.last?.screen.liveBoard
      #expect(board?.selectedFestivalID == selected.id)
      #expect(board?.selectedFestival?.name == selected.name)
      #expect(board?.cachedPacks.isEmpty == true)
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
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.router(.routeAction(id: 1, action: .liveBoard(.view(.loginTapped))))))))
    await store.receive {
      guard case .scope(.home(.auth(.view(.loginRequested(.none))))) = $0 else { return false }
      return true
    }
    guard case let .home(presented) = store.state else { return }
    #expect(presented.authFlow.presentation == .login)
  }

  @Test func restoredSessionWithoutOfflineEligibilityStillReachesLiveBoard() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in }, offlineEligible: { _ in false })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: "user-a",
      isLoggedIn: true
    ))))))
    await store.receive {
      guard case .scope(.home(.festival(.sessionChanged(hasSession: true, userID: "user-a")))) = $0 else { return false }
      return true
    }
    guard case let .home(updatedHome) = store.state else {
      Issue.record("세션 복원 후 홈 화면이 유지되어야 합니다")
      return
    }
    #expect(updatedHome.authInputs.session == .init(
      hasSession: true,
      userID: "user-a"
    ))
  }

  @Test func bookmarkReloadSynchronizesListAndLiveBoard() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    let store = TestStore(initialState: state) {
      FestivalCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
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
    let clock = TestClock()
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.continuousClock = clock
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

  @Test func timetableSetCarriesResolvedArtistImage() throws {
    let payload = #"{"id":"festival","stages":[{"id":"main","name":"메인 무대"}],"timetable":[{"id":"with-image","artist":"가수","stageId":"main","startsAt":"2026-10-30T12:00:00+09:00","endsAt":"2026-10-30T13:00:00+09:00","imageUrl":"/api/v1/festivals/images/a.webp"},{"id":"no-image","artist":"밴드","stageId":"main","startsAt":"2026-10-30T13:00:00+09:00","endsAt":"2026-10-30T14:00:00+09:00"}]}"#
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(payload.utf8))
    let resolved = try #require(URL(string: "https://example.com/api/v1/festivals/images/a.webp"))

    let sets = FestivalPackTimetableMapper.days(from: pack) { value in
      value == "/api/v1/festivals/images/a.webp" ? resolved : nil
    }.first?.sets ?? []

    #expect(sets.first { $0.id == "with-image" }?.imageURL == resolved)
    #expect(sets.first { $0.id == "no-image" }?.imageURL == nil)
  }

  @Test func flagTabFollowsSelectedFestival() async {
    var state = MainTabCoordinator.State()
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival-a")))
    let store = TestStore(initialState: state) { MainTabCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    await store.send(.tabTapped(.flag))
    await store.receive(\.selectTab) { $0.selectedTab = .flag }
    await store.receive({ $0.flagDirectoryAction == .festivalChanged("festival-a") }) {
      $0.flagState.festivalID = "festival-a"
      $0.flagState.generation = 1
    }
  }

  @Test func flagTabUsesSelectedFestivalPackZoneNames() async throws {
    let payload = #"{"id":"festival-a","zones":[{"id":"zone_a","name":"리벳 스테이지 앞 왼쪽"}]}"#
    var festival = FestivalFeature.State(selectedFestivalID: "festival-a")
    festival.selectedPack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(payload.utf8))
    var state = MainTabCoordinator.State()
    state.festivalState.routes.push(.liveBoard(festival))
    let store = TestStore(initialState: state) { MainTabCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    await store.send(.tabTapped(.flag))
    await store.receive(\.selectTab) {
      $0.selectedTab = .flag
      $0.flagState.directory.zoneNames = ["zone_a": "리벳 스테이지 앞 왼쪽"]
    }
    await store.receive({ $0.flagDirectoryAction == .festivalChanged("festival-a") }) {
      $0.flagState.festivalID = "festival-a"
      $0.flagState.generation = 1
    }
  }

  @Test func flagFollowLoginRequestOpensAppLoginSheet() async {
    let store = TestStore(initialState: MainTabCoordinator.State(selectedTab: .flag)) { MainTabCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    await store.send(.flagDirectory(.directory(.delegate(.loginRequested))))
    await store.receive(\.flagCoordinator.delegate.loginRequested)
    await store.receive {
      guard case .auth(.view(.loginRequested(.none))) = $0 else { return false }
      return true
    } assert: {
      $0.authFlow.generation = 1
      $0.authFlow.presentation = .login
    }
  }

  @Test func flagFollowTermsRequestRoutesToProfileRefresh() async {
    let store = TestStore(initialState: MainTabCoordinator.State(selectedTab: .flag)) { MainTabCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authService = StubAuthService(
        loggedIn: false,
        userID: nil
      )
    }

    await store.send(.flagDirectory(.directory(.delegate(.termsAcceptanceRequested))))
    await store.receive(\.flagCoordinator.delegate.termsAcceptanceRequested)
    // 이어지는 세션 재조회의 상태 변화는 세션 테스트가 검증한다.
    store.exhaustivity = .off
    await store.receive(\.session.view.retryProfile)
  }

  @Test func myLogoutClearsVisibleAccountOnlyAfterSuccess() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.hasSession = true
    let analytics = LockIsolated<[AnalyticsCall]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording(analytics)
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.view(.signOutRequested))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.accountOperation = .signOut
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    guard case let .home(loading) = store.state else { return }
    #expect(loading.authFlow.profile?.user.id == "user-a")
    await store.receive(\.scope.home.account.inner.finished) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      $0 = .home(home)
    }
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.authFlow.profile == nil)
    #expect(analytics.value == [.reset])
  }

  @Test func logoutUnbindsAndEndsLocalActivityBeforeSigningOut() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    let calls = LockIsolated<[String]>([])
    let activity = FestivalLiveActivityRecord(
      id: "activity-a",
      festivalID: "festival-a",
      phase: .upcoming,
      startDate: Date(timeIntervalSince1970: 0),
      endDate: nil
    )
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = UnauthenticatedAuthUseCase(calls: calls)
      $0.deviceRegistrationService = UnboundTestDevice(calls: calls)
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(
        activities: { [activity] },
        end: { id in calls.withValue { $0.append("end:\(id)") } }
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.view(.signOutRequested)))))
    await store.receive(\.scope.home.account.inner.finished)

    #expect(calls.value == ["unbind", "end:activity-a", "signOut"])
  }

  @Test func logoutContinuesWhenDeviceUnbindFails() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    let calls = LockIsolated<[String]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = UnauthenticatedAuthUseCase(calls: calls)
      $0.deviceRegistrationService = UnboundTestDevice(
        calls: calls,
        shouldFailUnbind: true
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.view(.signOutRequested)))))
    await store.receive(\.scope.home.account.inner.finished)

    #expect(calls.value == ["unbind", "signOut"])
    guard case let .home(signedOut) = store.state else { return }
    #expect(!signedOut.authFlow.hasSession)
  }

  @Test func withdrawalContinuesWhenDeviceUnbindFails() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    let calls = LockIsolated<[String]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = RecordingWithdrawalAuthUseCase(calls: calls)
      $0.deviceRegistrationService = UnboundTestDevice(
        calls: calls,
        shouldFailUnbind: true
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.view(.withdrawRequested)))))
    await store.receive(\.scope.home.account.inner.finished)

    #expect(calls.value == ["unbind", "withdraw"])
    guard case let .home(withdrawn) = store.state else { return }
    #expect(!withdrawn.authFlow.hasSession)
  }

  @Test func sessionExpiryDuringUnbindDoesNotCallWithdrawalOrRebind() async {
    let (
      started,
      signal
    ) = AsyncStream<Void>.makeStream()
    let gate = AccountUnbindGate(started: signal)
    var iterator = started.makeAsyncIterator()
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    let calls = LockIsolated<[String]>([])
    let store = Store(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = RecordingWithdrawalAuthUseCase(calls: calls)
      $0.deviceRegistrationService = SuspendedUnbindDevice(
        gate: gate,
        calls: calls
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }

    let operation = store.send(.scope(.home(.account(.view(.withdrawRequested)))))
    guard await iterator.next() != nil else {
      Issue.record("기기 바인딩 해제가 시작되지 않았어요")
      return
    }
    store.send(.scope(.home(.session(.view(.sessionExpired)))))
    await gate.failWithCancellation()
    await operation.finish()

    #expect(calls.value.filter { $0 == "withdraw" || $0 == "bind" }.isEmpty)
    guard case let .home(expired) = store.withState({ $0 }) else { return }
    #expect(!expired.authFlow.hasSession)
  }

  @Test func completedAccountOperationClosesSheetAfterSwitchingTabs() async {
    var home = MainTabCoordinator.State(selectedTab: .flag)
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.hasSession = true
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.inner(.finished(
      generation: 1,
      operation: .signOut,
      result: .success(())
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      $0 = .home(home)
    }
    // 계정이 사라지면 앱이 입력 액션으로 알리고 마이 화면이 계정 화면을 닫는다.
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged)
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.selectedTab == .flag)
    #expect(signedOut.profileState.destination == nil)
  }

  @Test func myWithdrawalFailureRetainsAccount() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.hasSession = true
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = FailingMyAuthUseCase()
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
    }

    await store.send(.scope(.home(.account(.view(.withdrawRequested))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.accountOperation = .withdraw
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged) { syncProfileAccount(&$0) }
    await store.receive(\.scope.home.profileCoordinator.profile.destination.presented.settings.view.accountChanged) {
      syncSettingsScreen(&$0)
    }
    await store.receive(
      \.scope.home.profileCoordinator.profile.destination.presented.settings.destination.presented.account.view.accountChanged
    ) {
      syncAccountScreen(&$0)
    }
    await store.receive(\.scope.home.account.inner.finished) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.accountOperationGeneration = nil
      home.authFlow.accountOperation = nil
      home.authFlow.isLoading = false
      home.authFlow.message = "회원 탈퇴에 실패했습니다. 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged) { syncProfileAccount(&$0) }
    await store.receive(\.scope.home.profileCoordinator.profile.destination.presented.settings.view.accountChanged) {
      syncSettingsScreen(&$0)
    }
    await store.receive(
      \.scope.home.profileCoordinator.profile.destination.presented.settings.destination.presented.account.view.accountChanged
    ) {
      syncAccountScreen(&$0)
    }
    guard case let .home(unchanged) = store.state else { return }
    #expect(unchanged.authFlow.profile?.user.id == "user-a")
    #expect(unchanged.profileState.destination?.settings?.destination?.account != nil)
  }

  @Test func withdrawalRefreshFailureClearsPreviousAccountWithoutExpiryEvent() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.bookedUserID = "user-a"
    board.bookedFestivalIDs = ["festival"]
    home.festivalState.routes.push(.liveBoard(board))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = FailingMyAuthUseCase(withdrawError: .offline)
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.view(.withdrawRequested)))))
    await store.receive(\.scope.home.session.view.sessionExpired)
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged)
    guard case let .home(cleared) = store.state else { return }
    #expect(!cleared.authFlow.hasSession)
    #expect(cleared.authFlow.profile == nil)
    #expect(cleared.authFlow.verifiedUserID == nil)
    #expect(cleared.profileState.destination == nil)
    #expect(cleared.authFlow.accountOperationGeneration == nil)
    #expect(cleared.authFlow.message?.contains("결과를 확인할 수 없어요") == true)
    #expect(cleared.festivalState.routes.last?.screen.liveBoard?.bookedFestivalIDs.isEmpty == true)
  }

  @Test func unauthenticatedWithdrawalClearsAccount() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.generation = 1
    home.authFlow.accountOperationGeneration = 1
    home.authFlow.isLoading = true
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.inner(.finished(
      generation: 1,
      operation: .withdraw,
      result: .failure(.notAuthenticated)
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow = .init()
      home.authFlow.generation = 1
      home.authFlow.message = "로그인이 만료되어 회원 탈퇴 결과를 확인할 수 없어요. 다시 로그인해 계정 상태를 확인해 주세요."
      $0 = .home(home)
    }
    // 계정이 사라지면 앱이 입력 액션으로 알리고 마이 화면이 계정 화면을 닫는다.
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged)
    guard case let .home(signedOut) = store.state else { return }
    #expect(!signedOut.authFlow.hasSession)
    #expect(signedOut.authFlow.profile == nil)
    #expect(signedOut.authFlow.verifiedUserID == nil)
    #expect(signedOut.profileState.destination == nil)
  }

  @Test func dismissingRetryWhileLoadingAllowsForegroundRefresh() async {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.authFlow.presentation = .retry
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.view(.dismissFlow))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.isLoading = false
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.offline)
    ))))))
    await store.send(.view(.foregrounded))
    await store.receive(\.scope.home.session.view.foregrounded) {
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.view(.dismissFlow))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.isLoading = false
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    let previous = eligibleProfile(id: "user-a").user
    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .success(previous)
    ))))))
    await store.send(.scope(.home(.account(.view(.signOutRequested))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 3
      home.authFlow.accountOperationGeneration = 3
      home.authFlow.accountOperation = .signOut
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 0,
      userID: nil,
      isLoggedIn: true
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.hasSession = true
      $0 = .home(home)
    }

    await store.send(.scope(.home(.account(.view(.signOutRequested))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.accountOperation = .signOut
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      $0 = .home(home)
    }
    await store.receive(\.scope.home.account.inner.finished) {
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival"))))))
    await store.send(.scope(.home(.account(.inner(.finished(
      generation: 1,
      operation: .signOut,
      result: .success(())
    )))))) {
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = UnauthenticatedAuthUseCase()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.festival(.delegate(.bookmarkRequested("festival"))))))
    await store.receive(\.scope.home.session.view.bookmarkRequested) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.pendingFestivalID = "festival"
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.sessionRestored) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.presentation = .login
      $0 = .home(home)
    }
    await store.receive(\.scope.home.session.inner.profileLoaded) {
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
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.view(.dismissFlow))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.presentation = nil
      $0 = .home(home)
    }
    await store.send(.scope(.home(.account(.inner(.finished(
      generation: 1,
      operation: .withdraw,
      result: .success(())
    )))))) {
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
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .failure(.offline)
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.isLoading = false
      home.authFlow.message = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged) { syncProfileAccount(&$0) }
    guard case let .home(unchanged) = store.state else { return }
    #expect(unchanged.authFlow.profile?.user.id == "user-a")
  }

  @Test func sessionExpiryClearsAccountDataOnlyWhileSignedIn() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.isLoading = true
    home.authFlow.signUp.nickname = "작성 중"
    home.authFlow.signUp.acceptedServiceTerms = true
    home.authFlow.signUp.acceptedPrivacyTerms = true
    home.authFlow.signUp.termsDraftVersion = "2026-10"
    home.authFlow.message = "이전 안내"
    home.authFlow.hasRetriedTermsUpdate = true
    home.authFlow.termsUpdateExhausted = true
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    home.timetableState.mySetIDs = ["set-a"]
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.hasSession = true
    board.sessionUserID = "user-a"
    board.bookedUserID = "user-a"
    board.bookedFestivalIDs = ["festival"]
    home.festivalState.routes.push(.liveBoard(board))
    expectFlagClearedImmediately(
      from: home,
      by: .scope(.home(.session(.view(.sessionExpired))))
    )
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.sessionExpired)))))
    await store.receive {
      guard case .scope(.home(.festival(.accountChanged))) = $0 else { return false }
      return true
    }
    await store.receive {
      guard case let .scope(.home(action)) = $0 else { return false }
      return action.flagDirectoryAction == .accountChanged
    }
    await store.receive {
      guard case .scope(.home(.timetable(.view(.accountChanged)))) = $0 else { return false }
      return true
    }
    await store.receive(\.scope.home.timetableCoordinator.timetable)
    guard case let .home(expired) = store.state else { return }
    #expect(!expired.authFlow.hasSession)
    #expect(expired.authFlow.profile == nil)
    #expect(expired.authFlow.verifiedUserID == nil)
    #expect(expired.authFlow.lastVerifiedUserID == nil)
    #expect(expired.authFlow.generation == 1)
    #expect(expired.authFlow.presentation == nil)
    #expect(!expired.authFlow.isLoading)
    #expect(expired.authFlow.signUp.nickname.isEmpty)
    #expect(!expired.authFlow.signUp.acceptedTerms)
    #expect(expired.authFlow.signUp.consentedVersion == nil)
    #expect(expired.authFlow.message == nil)
    #expect(!expired.authFlow.hasRetriedTermsUpdate)
    #expect(!expired.authFlow.termsUpdateExhausted)
    #expect(expired.flagState.snapshot == nil)
    #expect(expired.timetableState.mySetIDs.isEmpty)
    #expect(expired.festivalState.routes.last?.screen.liveBoard?.bookedFestivalIDs.isEmpty == true)

    await store.send(.scope(.home(.session(.view(.sessionExpired)))))
    guard case let .home(unchanged) = store.state else { return }
    #expect(unchanged.authFlow.generation == 1)
  }

  @Test func sessionExpiryKeepsPendingBookmarkAndPresentsLogin() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.isLoading = true
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingOwnerID = "user-a"
    home.authFlow.pendingShouldBeBooked = false
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    // 토큰 갱신 401은 프로필 실패 응답보다 만료 알림이 먼저 도착한다.
    await store.send(.scope(.home(.session(.view(.sessionExpired)))))
    guard case let .home(expired) = store.state else { return }
    #expect(expired.authFlow.presentation == .login)
    #expect(expired.authFlow.pendingFestivalID == "festival")
    #expect(expired.authFlow.pendingOwnerID == "user-a")
    #expect(expired.authFlow.pendingShouldBeBooked == false)
    #expect(!expired.authFlow.hasSession)
    #expect(!expired.authFlow.isLoading)
  }

  @Test func sessionExpiryRecoversDeviceAndEndsLocalActivity() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    let calls = LockIsolated<[String]>([])
    let activity = FestivalLiveActivityRecord(
      id: "activity-a",
      festivalID: "festival-a",
      phase: .upcoming,
      startDate: Date(timeIntervalSince1970: 0),
      endDate: nil
    )
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.deviceRegistrationService = UnboundTestDevice(calls: calls)
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(
        activities: { [activity] },
        end: { id in calls.withValue { $0.append("end:\(id)") } }
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.sessionExpired)))))
    await store.finish()

    #expect(calls.value == ["recover", "end:activity-a"])
  }

  @Test func sessionExpiryDropsPendingBookmarkWithoutKnownOwner() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    home.authFlow.isLoading = true
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingShouldBeBooked = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.sessionExpired)))))
    guard case let .home(expired) = store.state else { return }
    #expect(expired.authFlow.pendingFestivalID == nil)
    #expect(expired.authFlow.pendingOwnerID == nil)
    #expect(!expired.authFlow.pendingShouldBeBooked)
    #expect(expired.authFlow.presentation == nil)
  }

  @Test func sessionLossOnRestoreDropsPendingBookmarkWithoutKnownOwner() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingShouldBeBooked = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 0,
      userID: nil,
      isLoggedIn: false
    ))))))
    guard case let .home(restored) = store.state else { return }
    #expect(restored.authFlow.pendingFestivalID == nil)
    #expect(!restored.authFlow.pendingShouldBeBooked)
    #expect(restored.authFlow.presentation == nil)
  }

  @Test func signedOutProfileFailureKeepsLocalTimetableSelection() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.isLoading = true
    home.timetableState.mySetIDs = ["local-set"]
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.notAuthenticated)
    ))))))
    await store.finish()
    guard case let .home(signedOut) = store.state else { return }
    #expect(signedOut.timetableState.mySetIDs == ["local-set"])
  }

  @Test func sessionExpiryDuringAccountOperationDiscardsLateCompletionAfterNewLogin() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.generation = 2
    home.authFlow.accountOperationGeneration = 2
    home.authFlow.accountOperation = .withdraw
    home.authFlow.isLoading = true
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    home.timetableState.mySetIDs = ["set-a"]
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.bookedUserID = "user-a"
    board.bookedFestivalIDs = ["festival"]
    home.festivalState.routes.push(.liveBoard(board))
    let store = Store(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    store.send(.scope(.home(.session(.view(.sessionExpired)))))
    guard case let .home(expired) = store.withState({ $0 }) else { return }
    #expect(!expired.authFlow.hasSession)
    #expect(expired.authFlow.profile == nil)
    #expect(expired.profileState.destination == nil)
    #expect(expired.timetableState.mySetIDs.isEmpty)
    #expect(expired.flagState.snapshot == nil)
    #expect(expired.festivalState.routes.last?.screen.liveBoard?.bookedFestivalIDs.isEmpty == true)
    #expect(expired.authFlow.accountOperationGeneration == nil)
    #expect(expired.authFlow.accountOperation == nil)
    #expect(expired.authFlow.message?.contains("결과를 확인할 수 없어요") == true)

    store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 3,
      userID: "user-b",
      isLoggedIn: true
    ))))))
    store.send(.scope(.home(.account(.inner(.finished(
      generation: 2,
      operation: .withdraw,
      result: .success(())
    ))))))
    guard case let .home(newAccount) = store.withState({ $0 }) else { return }
    #expect(newAccount.authFlow.hasSession)
    #expect(newAccount.authFlow.lastVerifiedUserID == "user-b")
  }

  @Test func withdrawalFailureAfterExpiryCannotRestorePreviousAccount() async {
    let (started, signal) = AsyncStream<Void>.makeStream()
    let gate = WithdrawalGate(started: signal)
    var iterator = started.makeAsyncIterator()
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.profileState.hasSession = true
    home.profileState.destination = .settings(settingsWithAccount(AccountSettingsFeature.State(profile: nil)))
    let store = Store(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = SuspendedWithdrawalAuthUseCase(gate: gate)
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }

    let operation = store.send(.scope(.home(.account(.view(.withdrawRequested)))))
    guard await iterator.next() != nil else {
      Issue.record("회원 탈퇴 요청이 시작되지 않았어요")
      return
    }
    store.send(.scope(.home(.session(.view(.sessionExpired)))))
    await gate.fail()
    await operation.finish()

    guard case let .home(expired) = store.withState({ $0 }) else { return }
    #expect(!expired.authFlow.hasSession)
    #expect(expired.authFlow.profile == nil)
    #expect(expired.profileState.destination == nil)
    #expect(expired.authFlow.accountOperationGeneration == nil)
    #expect(expired.authFlow.message?.contains("결과를 확인할 수 없어요") == true)
  }

  @Test func sessionExpiryCancelsInFlightAccountOperationThroughDelegate() async {
    let (
      started,
      signal
    ) = AsyncStream<Void>.makeStream()
    let gate = WithdrawalGate(started: signal)
    var iterator = started.makeAsyncIterator()
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    // 취소되지 않으면 탈퇴 효과가 완료나 세션 만료 위임을 보낸다. 그 결과 액션이 오는지 기록한다.
    let operationResults = LockIsolated<[String]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      CombineReducers {
        AppCoordinator()
        Reduce<AppCoordinator.State, AppCoordinator.Action> { _, action in
          if action.is(\.scope.home.account.inner.finished) {
            operationResults.withValue { $0.append("finished") }
          }
          if action.is(\.scope.home.account.delegate.sessionExpired) {
            operationResults.withValue { $0.append("sessionExpired") }
          }
          return .none
        }
      }
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authUseCase = SuspendedWithdrawalAuthUseCase(gate: gate)
      $0.deviceRegistrationService = UnboundTestDevice()
      $0.authService = StubAuthService(
        loggedIn: false,
        userID: nil
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { _ in [] },
        save: { _, _ in }
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.account(.view(.withdrawRequested))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 1
      home.authFlow.accountOperationGeneration = 1
      home.authFlow.accountOperation = .withdraw
      home.authFlow.isLoading = true
      $0 = .home(home)
    }
    guard await iterator.next() != nil else {
      Issue.record("회원 탈퇴 요청이 시작되지 않았어요")
      return
    }
    await store.send(.scope(.home(.session(.view(.sessionExpired))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.generation = 2
      home.authFlow.accountOperationGeneration = nil
      home.authFlow.accountOperation = nil
      home.authFlow.isLoading = false
      home.authFlow.hasSession = false
      $0 = .home(home)
    }
    // 세션이 끝났다는 위임을 받은 홈이 계정 코디네이터에 진행 중인 작업 취소를 명령한다.
    await store.receive(\.scope.home.session.delegate.accountOperationInterrupted)
    await store.receive(\.scope.home.account.view.cancelOperation)
    await gate.fail()
    await store.finish()
    // 취소된 탈퇴 효과는 멈춘 요청이 실패로 끝나도 결과 액션을 보내지 않는다.
    #expect(operationResults.value.isEmpty)

    guard case let .home(expired) = store.state else { return }
    #expect(expired.authFlow.message == AuthFlowState.Message.sessionExpiredDuringWithdraw)
  }

  @Test func expiryNotificationIsSubscribedAfterSplashTransition() async {
    let (events, continuation) = AsyncStream<Void>.makeStream()
    let store = TestStore(initialState: AppCoordinator.State()) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authSessionExpiryClient = AuthSessionExpiryClient(events: { events })
      $0.festivalCatalogService = EmptyFestivalCatalogService()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-a"))
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
    }
    store.exhaustivity = .off

    await store.send(.inner(.completeHomeTransition))
    await store.receive(\.view.foregrounded)
    await store.receive(\.scope.home.session.inner.profileLoaded)
    guard case let .home(signedIn) = store.state else { return }
    #expect(signedIn.authFlow.hasSession)
    continuation.yield(())
    await store.receive(\.scope.home.session.view.sessionExpired)
    guard case let .home(expired) = store.state else { return }
    #expect(!expired.authFlow.hasSession)
    #expect(expired.authFlow.profile == nil)
    #expect(expired.authFlow.generation == signedIn.authFlow.generation + 1)
    continuation.finish()
    await store.finish()
  }

  @Test func restoredLogoutClearsPreviousFlagImmediately() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.hasSession = true
    home.authFlow.verifiedUserID = "user-a"
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    home.flagState.viewState = .loaded
    // 실제 Store에서 send 직후 상태를 확인해 이전 계정 깃발이 한 번도 남지 않음을 검증한다.
    let store = Store(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: nil,
      isLoggedIn: false
    ))))))
    guard case let .home(signedOut) = store.withState({ $0 }) else { return }
    #expect(signedOut.flagState.snapshot == nil)
    #expect(signedOut.flagState.viewState == .idle)
  }

  @Test func verifiedAccountSwitchClearsFlagAndTimetableAndLoadsNewBookmarks() async {
    var home = MainTabCoordinator.State()
    home.authFlow.hasSession = true
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.generation = 1
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    home.timetableState.mySetIDs = ["set-a"]
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.hasSession = true
    board.sessionUserID = "user-a"
    board.bookedUserID = "user-a"
    board.bookedFestivalIDs = ["booked-a"]
    home.festivalState.routes.push(.liveBoard(board))
    let bookedStore = FestivalBookedStore(
      load: { $0 == "user-b" ? ["booked-b"] : ["booked-a"] },
      save: { _, _ in },
      offlineEligible: { _ in true }
    )
    expectFlagClearedImmediately(
      from: home,
      by: .scope(.home(.session(.inner(.sessionRestored(
        generation: 1,
        userID: "user-b",
        isLoggedIn: true
      )))))
    ) { $0.festivalBookedStore = bookedStore }
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = bookedStore
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: "user-b",
      isLoggedIn: true
    ))))))
    await store.receive {
      guard case .scope(.home(.festival(.reloadBookmarks(userID: "user-b")))) = $0 else { return false }
      return true
    }
    await store.receive {
      guard case let .scope(.home(action)) = $0 else { return false }
      return action.flagDirectoryAction == .accountChanged
    }
    guard case let .home(switched) = store.state else { return }
    #expect(switched.flagState.snapshot == nil)
    await store.receive {
      guard case .scope(.home(.timetable(.view(.accountChanged)))) = $0 else { return false }
      return true
    }
    await store.receive(\.scope.home.timetableCoordinator.timetable)
    await store.receive {
      guard case .scope(.home(.festival(.sessionChanged(hasSession: true, userID: "user-b")))) = $0 else { return false }
      return true
    }
    await store.receive(\.scope.home.festival.router)
    await store.receive(\.scope.home.festival.router)
    guard case let .home(updated) = store.state else { return }
    #expect(updated.timetableState.mySetIDs.isEmpty)
    #expect(updated.festivalState.routes.last?.screen.liveBoard?.bookedUserID == "user-b")
    #expect(updated.festivalState.routes.last?.screen.liveBoard?.bookedFestivalIDs == ["booked-b"])

    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.offline)
    ))))))
    guard case let .home(offline) = store.state else { return }
    #expect(offline.festivalState.routes.last?.screen.liveBoard?.bookedUserID == "user-b")
    #expect(offline.festivalState.routes.last?.screen.liveBoard?.bookedFestivalIDs == ["booked-b"])
  }

  @Test func loginFromSignedOutDoesNotDiscardLocalTimetableSelection() async {
    var home = MainTabCoordinator.State()
    home.timetableState.mySetIDs = ["local-set"]
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in }, offlineEligible: { _ in true })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 0,
      userID: "user-a",
      isLoggedIn: true
    ))))))
    await store.receive {
      guard case .scope(.home(.festival(.sessionChanged(hasSession: true, userID: "user-a")))) = $0 else { return false }
      return true
    }
    guard case let .home(loggedIn) = store.state else { return }
    #expect(loggedIn.timetableState.mySetIDs == ["local-set"])
  }

  @Test(arguments: [false, true])
  func loginFromSignedOutReloadsFlagsForSignedInAccount(hasLegacyBookmarks: Bool) async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.loginAttemptGeneration = 1
    home.authFlow.presentation = .login
    home.flagState = FestivalFlagFeature.State(festivalID: "festival")
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    home.flagState.viewState = .loaded
    let bookedStore = FestivalBookedStore(
      load: { _ in [] },
      save: { _, _ in },
      legacyBookmarks: { hasLegacyBookmarks ? ["legacy"] : [] }
    )
    let dependencies: @Sendable (inout DependencyValues) -> Void = {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-a"))
      $0.festivalBookedStore = bookedStore
    }
    let result = AuthLoginResult(newUser: false, user: eligibleProfile(id: "user-a").user)
    expectFlagClearedImmediately(
      from: home,
      by: .scope(.home(.auth(.login(.delegate(.signedIn(result)))))),
      dependencies: dependencies
    )
    let store = TestStore(
      initialState: AppCoordinator.State.home(home),
      reducer: { AppCoordinator() },
      withDependencies: dependencies
    )
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(result)))))))
    await store.finish()
    await store.skipReceivedActions()
    guard case let .home(signedIn) = store.state else { return }
    #expect(signedIn.flagState.snapshot == nil)
    #expect(signedIn.flagState.viewState == .idle)
    guard case let .home(finished) = store.state else { return }
    #expect(finished.authFlow.presentation == (hasLegacyBookmarks ? .migration : nil))
  }

  @Test func losingVerifiedAccountIDWhileSignedInClearsFlagAndTimetable() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.hasSession = true
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    home.timetableState.mySetIDs = ["set-a"]
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    // 세션은 남았지만 저장된 계정 ID를 읽지 못하면 다음 프로필이 다른 계정일 수 있다(A→nil→B).
    await store.send(.scope(.home(.session(.inner(.sessionRestored(
      generation: 1,
      userID: nil,
      isLoggedIn: true
    ))))))
    await store.receive { $0.homeFlagDirectoryAction == .accountChanged }
    await store.receive(\.scope.home.timetable.view.accountChanged)
    await store.receive(\.scope.home.timetableCoordinator.timetable)
    guard case let .home(cleared) = store.state else { return }
    #expect(cleared.flagState.snapshot == nil)
    #expect(cleared.timetableState.mySetIDs.isEmpty)
  }

  @Test func profile401AfterRestoredLogoutKeepsSignedOutLiveBoard() async {
    let snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.liveBoard = snapshot
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.festivalState.routes.push(.liveBoard(board))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    // `sessionRestored`가 이미 로그아웃을 정리한 뒤 받은 비로그인 보드는 뒤따르는 401로 지우지 않는다.
    await store.send(.scope(.home(.session(.inner(.profileLoaded(
      generation: 1,
      .failure(.notAuthenticated)
    ))))))
    await store.receive(\.scope.home.festival.accountChanged)
    guard case let .home(updated) = store.state else { return }
    #expect(updated.festivalState.routes.last?.screen.liveBoard?.liveBoard == snapshot)
  }

  @Test func profileUpdateForDifferentAccountClearsPreviousAccountData() async {
    let previous = eligibleProfile(id: "user-a")
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.hasSession = true
    home.authFlow.profile = previous
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.isLoading = true
    home.flagState.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil
    )
    home.timetableState.mySetIDs = ["set-a"]
    let other = eligibleProfile(id: "user-b").user
    expectFlagClearedImmediately(
      from: home,
      by: .scope(.home(.session(.view(.signUpSubmitted(
        generation: 1,
        .success(other)
      )))))
    )
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.session(.view(.signUpSubmitted(
      generation: 1,
      .success(other)
    ))))))
    await store.receive { $0.homeFlagDirectoryAction == .accountChanged }
    await store.receive(\.scope.home.timetable.view.accountChanged)
    await store.receive(\.scope.home.timetableCoordinator.timetable)
    guard case let .home(cleared) = store.state else { return }
    #expect(cleared.authFlow.lastVerifiedUserID == nil)
    #expect(cleared.flagState.snapshot == nil)
    #expect(cleared.timetableState.mySetIDs.isEmpty)
  }

  /// 실제 Store는 `Effect.send`를 같은 send 호출 안에서 처리하므로, 부모 액션 직후 이전 계정 깃발이 남지 않아야 한다.
  private func expectFlagClearedImmediately(
    from home: MainTabCoordinator.State,
    by action: AppCoordinator.Action,
    dependencies: @escaping @Sendable (inout DependencyValues) -> Void = { _ in }
  ) {
    let store = Store(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      dependencies(&$0)
    }
    store.send(action)
    guard case let .home(updated) = store.withState({ $0 }) else {
      Issue.record("홈 상태가 아니에요")
      return
    }
    #expect(updated.flagState.snapshot == nil)
    #expect(updated.flagState.viewState == .idle)
  }

  @Test func acceptedLoginCommitsSessionBeforeSignedInTransition() async {
    let sessionID = UUID()
    let auth = SessionRecordingAuthService()
    let analytics = LockIsolated<[AnalyticsCall]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(loginSheetHome())) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording(analytics)
      $0.authService = auth
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-a"))
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
      $0.authUseCase = SessionForwardingAuthUseCase(
        base: $0.authUseCase,
        auth: $0.authService
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(loginResult(sessionID))))))))
    guard case let .home(pending) = store.state else { return }
    #expect(!pending.authFlow.hasSession)
    await store.receive(\.scope.home.auth.inner.loginCommitted)
    guard case let .home(committed) = store.state else { return }
    #expect(committed.authFlow.hasSession)
    #expect(committed.authFlow.verifiedUserID == "user-a")
    #expect(await auth.committed == [sessionID])
    // 기존 계정은 sign_up 없이 사용자만 연결한다.
    #expect(analytics.value == [.identify("user-a", "apple")])
    await store.receive(\.scope.home.session.inner.profileLoaded)
  }

  @Test func acceptedNewUserLoginTracksSignUp() async {
    let analytics = LockIsolated<[AnalyticsCall]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(loginSheetHome())) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording(analytics)
      $0.authService = SessionRecordingAuthService()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: eligibleProfile(id: "user-a"))
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
      $0.authUseCase = SessionForwardingAuthUseCase(
        base: $0.authUseCase,
        auth: $0.authService
      )
    }
    store.exhaustivity = .off
    let result = AuthLoginResult(newUser: true, user: eligibleProfile(id: "user-a").user, sessionID: UUID())

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(result)))))))
    await store.receive(\.scope.home.auth.inner.loginCommitted)
    #expect(analytics.value == [.identify("user-a", "apple"), .track(.signUp(method: .apple))])
    await store.receive(\.scope.home.session.inner.profileLoaded)
  }

  @Test func failedCommitKeepsLoginOpenWithError() async {
    let auth = SessionRecordingAuthService(commitResult: false)
    let analytics = LockIsolated<[AnalyticsCall]>([])
    let store = TestStore(initialState: AppCoordinator.State.home(loginSheetHome())) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording(analytics)
      $0.authService = auth
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
      $0.authUseCase = SessionForwardingAuthUseCase(
        base: $0.authUseCase,
        auth: $0.authService
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(loginResult(UUID()))))))))
    await store.receive(\.scope.home.auth.inner.loginCommitted)
    guard case let .home(rejected) = store.state else { return }
    #expect(!rejected.authFlow.hasSession)
    #expect(rejected.authFlow.verifiedUserID == nil)
    #expect(rejected.authFlow.loginAttemptGeneration == nil)
    #expect(rejected.authFlow.presentation == .login)
    #expect(rejected.authFlow.message == "로그인 정보를 저장하지 못했어요. 다시 시도해 주세요.")
    #expect(!rejected.authFlow.isLoading)
    #expect(analytics.value.isEmpty)
  }

  @Test func loginFinishedAfterSheetDismissalDiscardsItsSession() async {
    let sessionID = UUID()
    let auth = SessionRecordingAuthService()
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 2
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authService = auth
      $0.authUseCase = SessionForwardingAuthUseCase(
        base: $0.authUseCase,
        auth: $0.authService
      )
    }

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(loginResult(sessionID))))))))
    await store.finish()
    #expect(await auth.discarded == [sessionID])
    #expect(await auth.committed.isEmpty)
  }

  @Test func commitFinishedAfterDismissalDoesNotCloseNewLoginSheet() async {
    let sessionID = UUID()
    let auth = SessionRecordingAuthService(holdsCommit: true)
    let store = TestStore(initialState: AppCoordinator.State.home(loginSheetHome())) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authService = auth
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
      $0.authUseCase = SessionForwardingAuthUseCase(
        base: $0.authUseCase,
        auth: $0.authService
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(loginResult(sessionID))))))))
    await auth.waitUntilCommitStarts()
    await store.send(.scope(.home(.auth(.view(.dismissFlow)))))
    await store.send(.scope(.home(.auth(.view(.loginRequested(nil))))))
    await auth.releaseCommit()
    await store.receive(\.scope.home.auth.inner.loginCommitted)
    await store.finish()
    guard case let .home(reopened) = store.state else { return }
    // 이전 확정은 새로 연 로그인 시트를 닫거나 프로필을 다시 읽지 않고, 닫은 로그인의 세션만 되돌린다.
    #expect(reopened.authFlow.presentation == .login)
    #expect(!reopened.authFlow.isLoading)
    #expect(!reopened.authFlow.hasSession)
    #expect(await auth.revoked == [sessionID])
  }

  @Test func commitFinishedAfterDismissalRevokesDismissedSession() async {
    let sessionID = UUID()
    let auth = SessionRecordingAuthService(holdsCommit: true)
    let store = TestStore(initialState: AppCoordinator.State.home(loginSheetHome())) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.analyticsUseCase = .recording()
      $0.authService = auth
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
      $0.authUseCase = SessionForwardingAuthUseCase(
        base: $0.authUseCase,
        auth: $0.authService
      )
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.login(.delegate(.signedIn(loginResult(sessionID))))))))
    await auth.waitUntilCommitStarts()
    await store.send(.scope(.home(.auth(.view(.dismissFlow)))))
    await auth.releaseCommit()
    await store.receive(\.scope.home.auth.inner.loginCommitted)
    await store.receive(\.scope.home.auth.inner.staleLoginDiscarded)
    await store.finish()
    guard case let .home(dismissed) = store.state else { return }
    // 닫힘이 확정보다 먼저면 임시 세션을 버리고, 확정이 먼저 끝났으면 그 세션만 되돌린다.
    #expect(await auth.discarded == [sessionID])
    #expect(await auth.revoked == [sessionID])
    #expect(!dismissed.authFlow.hasSession)
    #expect(await auth.isLoggedIn == false)
  }

  @Test func reopenedLoginTapAdoptsInFlightLogin() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 3
    home.authFlow.presentation = .login
    home.authFlow.login.isSigningIn = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    // 진행 중인 로그인을 새로 시작하지 않고 이번 시도로 받는다(효과 없음).
    await store.send(.scope(.home(.auth(.view(.startLogin(.apple)))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.loginAttemptGeneration = 3
      $0 = .home(home)
    }
  }

  @Test func loginTapWhileCommittingDoesNotStartAnotherLogin() async {
    var home = loginSheetHome()
    home.authFlow.pendingCommitSessionID = UUID()
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }

    // 확정 중에는 새 로그인을 시작하지 않는다(상태·효과 없음).
    await store.send(.scope(.home(.auth(.view(.startLogin(.google))))))
  }

  @Test func loginSheetTapAsksParentThenStartsLogin() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.presentation = .login
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.oauthUseCase = CancelledOAuthUseCase()
    }

    // 로그인 시트 탭은 부모에게 요청하고, 부모가 시트 상태를 확인한 뒤 로그인을 시작한다.
    await store.send(.scope(.home(.auth(.login(.view(.signInTapped(.apple)))))))
    await store.receive(\.scope.home.auth.login.delegate.signInRequested) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.loginAttemptGeneration = 1
      $0 = .home(home)
    }
    await store.receive(\.scope.home.auth.login.view.signIn) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.login.isSigningIn = true
      $0 = .home(home)
    }
    await store.receive(\.scope.home.auth.login.async.signIn)
    await store.receive(\.scope.home.auth.login.inner.signInFailed) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.login.isSigningIn = false
      $0 = .home(home)
    }
  }

  @Test func loginSheetTapWithoutLoginSheetDoesNotStartLogin() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) { AppCoordinator() }

    // 로그인 시트가 아니면 부모가 요청을 무시한다(상태·효과 없음).
    await store.send(.scope(.home(.auth(.login(.view(.signInTapped(.google)))))))
    await store.receive(\.scope.home.auth.login.delegate.signInRequested)
  }

  @Test func loginSheetTapWhileCommittingDoesNotStartAnotherLogin() async {
    var home = loginSheetHome()
    home.authFlow.pendingCommitSessionID = UUID()
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }

    await store.send(.scope(.home(.auth(.login(.view(.signInTapped(.google)))))))
    await store.receive(\.scope.home.auth.login.delegate.signInRequested)
  }

  @Test func loginSheetCopyFollowsSelectedTab() async {
    var home = loginSheetHome()
    home.selectedTab = .live
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }

    // 로그인 시트가 떠 있을 때 탭이 바뀌면 부모가 문맥을 입력 액션으로 알린다.
    await store.send(.scope(.home(.selectTab(.my)))) {
      guard case var .home(home) = $0 else { return }
      home.previousTab = .live
      home.selectedTab = .my
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.auth.login.view.contextChanged) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.login.context = .profile
      $0 = .home(home)
    }
  }

  @Test func loginSheetContextIsNotSentWhileLoginIsHidden() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) { AppCoordinator() }

    // 로그인 시트가 없으면 탭이 바뀌어도 로그인 State에 알리지 않는다.
    await store.send(.scope(.home(.selectTab(.my)))) {
      guard case var .home(home) = $0 else { return }
      home.previousTab = .live
      home.selectedTab = .my
      $0 = .home(home)
    }
  }

  @Test func loginSheetReceivesFlowMessageWhileLoginIsPresented() async {
    let sessionID = UUID()
    var home = loginSheetHome()
    home.authFlow.pendingCommitSessionID = sessionID
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }

    await store.send(.scope(.home(.auth(.inner(.loginCommitted(
      loginResult(sessionID),
      generation: 1,
      committed: false
    )))))) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.pendingCommitSessionID = nil
      home.authFlow.loginAttemptGeneration = nil
      home.authFlow.message = "로그인 정보를 저장하지 못했어요. 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.authInputsChanged)
    await store.receive(\.scope.home.auth.login.view.contextChanged) {
      guard case var .home(home) = $0 else { return }
      home.authFlow.login.flowMessage = "로그인 정보를 저장하지 못했어요. 다시 시도해 주세요."
      $0 = .home(home)
    }
    await store.receive(\.scope.home.profileCoordinator.profile.view.accountChanged) { syncProfileAccount(&$0) }
  }

  @Test func signUpSheetReceivesFlowValuesAndConfiguredLegalURL() async {
    let profile = AuthProfile(user: signUpUser("user-a"), currentTermsVersion: "2026-10")
    var home = MainTabCoordinator.State()
    home.authFlow.profile = profile
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = ReturningProfileAuthUseCase(profile: profile)
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    // 가입 시트가 열리면 부모가 흐름 값을 입력 액션으로 넘기고, 약관 주소는 앱 설정 값을 쓴다.
    await store.send(.view(.foregrounded))
    await store.receive(\.scope.home.session.inner.profileLoaded)
    await store.receive(\.scope.home.auth.signUp.view.flowChanged)
    await store.receive(\.scope.home.auth.signUp.router)
    guard let signUp = signUpState(store.state) else { Issue.record("홈 상태가 아니다"); return }
    #expect(signUp.canOpenLegal)
    #expect(signUp.isSubmitting == false)
    #expect(signUp.legalURL(for: .terms) == LegalDocumentURL.baseURL?.appending(path: "terms"))
  }

  @Test func closingSignUpAlsoClosesLegalDocument() async {
    var home = MainTabCoordinator.State()
    home.authFlow.presentation = .onboarding
    home.authFlow.signUp = SignUpFeature.State()
    home.authFlow.signUp.nickname = "테스터"
    guard let privacyURL = home.authFlow.signUp.legalURL(for: .privacy) else {
      Issue.record("개인정보 약관 주소를 만들지 못했어요")
      return
    }
    home.authFlow.signUpFlow.routes.push(.legalDocument(.init(
      url: privacyURL,
      title: "개인정보 수집 · 이용"
    )))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() }
    store.exhaustivity = .off

    guard case let .home(opened) = store.state else { Issue.record("홈 상태가 아니다"); return }
    #expect(opened.authFlow.signUpFlow.routes.count == 2)

    // 가입 화면을 닫으면 그 위의 약관 상세도 닫고 초안은 남긴다.
    await store.send(.scope(.home(.auth(.view(.dismissFlow)))))
    await store.receive(\.scope.home.auth.signUp.view.sheetClosed)
    guard case let .home(closed) = store.state else { Issue.record("홈 상태가 아니다"); return }
    #expect(closed.authFlow.signUpFlow.routes.count == 1)
    #expect(signUpState(store.state)?.nickname == "테스터")
  }

  @Test func switchingFromSignUpToRetryClosesLegalDocument() async {
    var home = MainTabCoordinator.State()
    home.authFlow.profile = eligibleProfile(id: "user-a")
    home.authFlow.verifiedUserID = "user-a"
    home.authFlow.lastVerifiedUserID = "user-a"
    home.authFlow.pendingFestivalID = "festival"
    home.authFlow.pendingOwnerID = "user-a"
    home.authFlow.presentation = .onboarding
    home.authFlow.signUp = SignUpFeature.State()
    guard let termsURL = home.authFlow.signUp.legalURL(for: .terms) else {
      Issue.record("서비스 약관 주소를 만들지 못했어요")
      return
    }
    home.authFlow.signUpFlow.routes.push(.legalDocument(.init(
      url: termsURL,
      title: "서비스 이용약관"
    )))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authUseCase = FailingProfileAuthUseCase(failure: .server)
      $0.authService = StubAuthService(loggedIn: true, userID: "user-a")
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    guard case let .home(opened) = store.state else { Issue.record("홈 상태가 아니다"); return }
    #expect(opened.authFlow.signUpFlow.routes.count == 2)

    // 약관이 열린 채 포그라운드 갱신이 실패해 재시도 시트로 바뀌면 약관 상세도 닫힌다.
    await store.send(.view(.foregrounded))
    await store.receive(\.scope.home.session.inner.profileLoaded)
    // 약관 상세를 닫는 중간 액션 경로는 구현에 따라 달라지므로 최종 상태로 확인한다.
    await store.skipReceivedActions()
    guard case let .home(after) = store.state else { Issue.record("홈 상태가 아니다"); return }
    #expect(after.authFlow.presentation == .retry)
    #expect(after.authFlow.signUpFlow.routes.count == 1)
  }

  @Test func revokedLoginRestoredByForegroundIsRereadAsSignedOut() async {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.hasSession = true
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
      $0.authService = StubAuthService(loggedIn: false, userID: nil)
      $0.festivalBookedStore = FestivalBookedStore(load: { _ in [] }, save: { _, _ in })
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.auth(.inner(.staleLoginDiscarded)))))
    await store.receive(\.scope.home.session.inner.sessionRestored)
    guard case let .home(reread) = store.state else { return }
    #expect(!reread.authFlow.hasSession)
  }

  private func launchLoginHome() -> MainTabCoordinator.State {
    var home = MainTabCoordinator.State()
    home.authFlow.presentation = .launchLogin
    return home
  }

  private func loginSheetHome() -> MainTabCoordinator.State {
    var home = MainTabCoordinator.State()
    home.authFlow.generation = 1
    home.authFlow.loginAttemptGeneration = 1
    home.authFlow.presentation = .login
    return home
  }

  private func loginResult(_ sessionID: UUID) -> AuthLoginResult {
    AuthLoginResult(newUser: false, user: eligibleProfile(id: "user-a").user, sessionID: sessionID)
  }

  @Test func timetableSaveUpdatesVisibleLiveBoard() async {
    var home = MainTabCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.hasSession = true
    board.isLiveBoardVisible = true
    home.festivalState.routes.push(.liveBoard(board))
    let store = TestStore(initialState: AppCoordinator.State.home(home)) { AppCoordinator() } withDependencies: {
      $0.useAppCoordinatorFestivalUseCases()
    }
    store.exhaustivity = .off

    await store.send(.scope(.home(.timetable(.delegate(.scheduleSaved(festivalID: "festival", setIDs: ["set-a"]))))))
    await store.receive {
      guard case .scope(.home(.festival(.myScheduleSaved(festivalID: "festival", setIDs: ["set-a"])))) = $0 else { return false }
      return true
    }
    await store.receive {
      guard case .scope(.home(.festival(.router(.routeAction(id: 1, action: .liveBoard(.view(.myScheduleSaved))))))) = $0 else { return false }
      return true
    }
    guard case let .home(updated) = store.state else { return }
    #expect(updated.festivalState.routes.last?.screen.liveBoard?.mySchedule?.setIDs == ["set-a"])
  }
}

private struct FailingMyAuthUseCase: AuthUseCaseInterface {
  var withdrawError: AuthDomainError = .unavailable
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.notAuthenticated }
  func fetchProfile() async throws -> AuthProfile { throw AuthDomainError.notAuthenticated }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.notAuthenticated
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.invalidResponse }
  func signOut() async throws { throw AuthDomainError.unavailable }
  func withdraw() async throws { throw withdrawError }

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}

private actor WithdrawalGate {
  private let started: AsyncStream<Void>.Continuation
  private var continuation: CheckedContinuation<Void, Error>?

  init(started: AsyncStream<Void>.Continuation) { self.started = started }

  func wait() async throws {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      started.yield(())
    }
  }

  func fail() {
    continuation?.resume(throwing: AuthDomainError.offline)
    continuation = nil
  }
}

private struct SuspendedWithdrawalAuthUseCase: AuthUseCaseInterface {
  let gate: WithdrawalGate

  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.notAuthenticated }
  func fetchProfile() async throws -> AuthProfile { throw AuthDomainError.notAuthenticated }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.notAuthenticated
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.invalidResponse }
  func signOut() async throws { throw AuthDomainError.notAuthenticated }
  func withdraw() async throws { try await gate.wait() }

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}

private struct UnauthenticatedAuthUseCase: AuthUseCaseInterface {
  let calls: LockIsolated<[String]>?

  init(calls: LockIsolated<[String]>? = nil) { self.calls = calls }

  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    throw AuthDomainError.notAuthenticated
  }

  func fetchProfile() async throws -> AuthProfile {
    throw AuthDomainError.notAuthenticated
  }

  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.notAuthenticated
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.invalidResponse }

  func signOut() async throws { calls?.withValue { $0.append("signOut") } }
  func withdraw() async throws {}

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}

private struct RecordingWithdrawalAuthUseCase: AuthUseCaseInterface {
  let calls: LockIsolated<[String]>

  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.notAuthenticated }
  func fetchProfile() async throws -> AuthProfile { throw AuthDomainError.notAuthenticated }
  func updateProfile(
    nickname: String,
    termsVersion: String,
    pushOptIn: Bool
  ) async throws -> AuthUser {
    throw AuthDomainError.notAuthenticated
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.notAuthenticated }
  func signOut() async throws { calls.withValue { $0.append("signOut") } }
  func withdraw() async throws { calls.withValue { $0.append("withdraw") } }

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
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
    case .server: throw AuthDomainError.unavailable
    case .missingVersion: throw AuthDomainError.invalidResponse
    }
  }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.invalidResponse
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.invalidResponse }
  func signOut() async throws {}
  func withdraw() async throws {}

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}

private struct ReturningProfileAuthUseCase: AuthUseCaseInterface {
  let profile: AuthProfile
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.invalidResponse }
  func fetchProfile() async throws -> AuthProfile { profile }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.invalidResponse
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.invalidResponse }
  func signOut() async throws {}
  func withdraw() async throws {}

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}

private struct OutdatedTermsAuthUseCase: AuthUseCaseInterface {
  let profile: AuthProfile
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.invalidResponse }
  func fetchProfile() async throws -> AuthProfile { profile }
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    throw AuthDomainError.termsVersionOutdated
  }
  func updateNickname(_ nickname: String) async throws -> AuthUser { throw AuthDomainError.invalidResponse }
  func signOut() async throws {}
  func withdraw() async throws {}

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}

/// 세션 확정·폐기 호출은 기록 대역 인증 서비스로 넘기고 나머지 호출은 `base`에 맡긴다.
private struct SessionForwardingAuthUseCase: AuthUseCaseInterface {
  let base: any AuthUseCaseInterface
  let auth: any AuthService

  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    return try await base.signIn(with: credential)
  }

  func fetchProfile() async throws -> AuthProfile {
    return try await base.fetchProfile()
  }

  func updateProfile(
    nickname: String,
    termsVersion: String,
    pushOptIn: Bool
  ) async throws -> AuthUser {
    return try await base.updateProfile(
      nickname: nickname,
      termsVersion: termsVersion,
      pushOptIn: pushOptIn
    )
  }

  func updateNickname(_ nickname: String) async throws -> AuthUser {
    return try await base.updateNickname(nickname)
  }

  func signOut() async throws {
    try await base.signOut()
  }

  func withdraw() async throws {
    try await base.withdraw()
  }

  func commitSession(_ id: UUID) async -> Bool {
    return await auth.commitSession(id)
  }

  func discardSession(_ id: UUID) async -> Bool {
    return await auth.discardSession(id)
  }

  func signOut(ifSession id: UUID) async -> Bool {
    return await auth.signOut(ifSession: id)
  }
}

struct StubAuthService: AuthService {
  let loggedIn: Bool
  let userID: String?
  let sessionID = UUID()

  var isLoggedIn: Bool { get async { loggedIn } }
  var authenticatedSessionID: UUID? { get async { loggedIn ? sessionID : nil } }
  var hasPendingLocalClear: Bool { get async { false } }
  var hasUnconfirmedRevocation: Bool { get async { false } }
  var hasPendingSignOutCleanup: Bool { get async { false } }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { get async { false } }
  var hasPendingWithdrawalCleanup: Bool { get async { false } }
  var currentUserID: String? { get async { userID } }
  var refreshToken: String? {
    get async {
      Issue.record("테스트에서 refreshToken 조회를 예상하지 않았어요")
      return nil
    }
  }

  func stageSession(accessToken: String, refreshToken: String) async -> UUID {
    Issue.record("테스트에서 stageSession 호출을 예상하지 않았어요")
    return UUID()
  }

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("테스트에서 commitSession 호출을 예상하지 않았어요")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("테스트에서 discardSession 호출을 예상하지 않았어요")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("테스트에서 signOut(ifSession:) 호출을 예상하지 않았어요")
    return false
  }

  func rememberUserID(_ userID: String) async {
    Issue.record("테스트에서 rememberUserID 호출을 예상하지 않았어요")
  }

  func signOut() async -> Bool {
    Issue.record("테스트에서 signOut 호출을 예상하지 않았어요")
    return false
  }

  func signOut(ifSessionIDMatches _: UUID) async -> Bool {
    Issue.record("테스트에서 조건부 signOut 호출을 예상하지 않았어요")
    return false
  }

  func prepareRevocation(_: AuthRevocationKind, ifSessionIDMatches _: UUID) async -> Bool { false }
  func finishRevocationRequest() async {}
  func confirmSignOut() async -> Bool { false }
  func confirmWithdrawalAuthorizationRejected() async -> Bool { false }
  func retryUnconfirmedLocalCleanup() async -> Bool { false }
  func completeWithdrawal() async -> Bool { false }
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

private func signUpState(_ state: AppCoordinator.State) -> SignUpFeature.State? {
  guard case let .home(home) = state else { return nil }
  return home.authFlow.signUp
}

private struct SucceedingOAuthUseCase: OAuthUseCaseInterface {
  let result: AuthLoginResult

  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    return result
  }
}

private struct CancelledOAuthUseCase: OAuthUseCaseInterface {
  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    throw AuthDomainError.userCancelled
  }
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

/// 세션 확정·폐기 호출을 기록하고, 필요하면 확정을 멈춰 두어 액션 순서를 조절한다.
private actor SessionRecordingAuthService: AuthService {
  private let commitResult: Bool
  private let holdsCommit: Bool
  private var loggedIn = false
  private var activeSessionID = UUID()
  private var commitStarted = false
  private var release: CheckedContinuation<Void, Never>?
  private(set) var committed: [UUID] = []
  private(set) var discarded: [UUID] = []
  private(set) var revoked: [UUID] = []

  init(commitResult: Bool = true, holdsCommit: Bool = false) {
    self.commitResult = commitResult
    self.holdsCommit = holdsCommit
  }

  var isLoggedIn: Bool { loggedIn }
  var sessionID: UUID { activeSessionID }
  var authenticatedSessionID: UUID? { loggedIn ? activeSessionID : nil }
  var hasPendingLocalClear: Bool { false }
  var hasUnconfirmedRevocation: Bool { false }
  var hasPendingSignOutCleanup: Bool { false }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { false }
  var hasPendingWithdrawalCleanup: Bool { false }
  var refreshToken: String? { nil }
  var currentUserID: String? { loggedIn ? "user-a" : nil }

  func stageSession(accessToken: String, refreshToken: String) -> UUID { UUID() }

  func commitSession(_ id: UUID) async -> Bool {
    commitStarted = true
    if holdsCommit { await withCheckedContinuation { release = $0 } }
    committed.append(id)
    if commitResult {
      activeSessionID = UUID()
      loggedIn = true
    }
    return commitResult
  }

  func discardSession(_ id: UUID) -> Bool {
    discarded.append(id)
    return true
  }

  func signOut(ifSession id: UUID) -> Bool {
    guard committed.last == id, loggedIn else { return false }
    revoked.append(id)
    loggedIn = false
    return true
  }

  func rememberUserID(_ userID: String) {}
  func signOut() -> Bool {
    activeSessionID = UUID()
    loggedIn = false
    return true
  }
  func signOut(ifSessionIDMatches expected: UUID) -> Bool {
    guard activeSessionID == expected, loggedIn else { return false }
    return signOut()
  }

  func prepareRevocation(_: AuthRevocationKind, ifSessionIDMatches _: UUID) -> Bool { false }
  func finishRevocationRequest() {}
  func confirmSignOut() -> Bool { false }
  func confirmWithdrawalAuthorizationRejected() -> Bool { false }
  func retryUnconfirmedLocalCleanup() -> Bool { false }
  func completeWithdrawal() -> Bool { false }

  func waitUntilCommitStarts() async {
    while !commitStarted || (holdsCommit && release == nil) { await Task.yield() }
  }

  func releaseCommit() {
    release?.resume()
    release = nil
  }
}

private enum AnalyticsCall: Equatable {
  case identify(String, String?)
  case track(AnalyticsEvent)
  case reset
}

private struct UnboundTestDevice: DeviceRegistrationService {
  let calls: LockIsolated<[String]>?
  let shouldFailUnbind: Bool

  init(
    calls: LockIsolated<[String]>? = nil,
    shouldFailUnbind: Bool = false
  ) {
    self.calls = calls
    self.shouldFailUnbind = shouldFailUnbind
  }

  func installationDeviceID() async throws -> String { return "test-device" }
  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    return DeviceAuthorization(
      deviceID: "test-device",
      bearerToken: "test-token"
    )
  }
  func authorization() async throws -> DeviceAuthorization? { return nil }
  func linkDeviceToCurrentUser() async throws {}
  func unbindCurrentUser() async throws {
    calls?.withValue { $0.append("unbind") }
    if shouldFailUnbind { throw DeviceUnbindTestError.unavailable }
  }
  func recoverBoundDevice() async throws { calls?.withValue { $0.append("recover") } }
}

private actor AccountUnbindGate {
  private let started: AsyncStream<Void>.Continuation
  private var continuation: CheckedContinuation<Void, Error>?

  init(started: AsyncStream<Void>.Continuation) { self.started = started }

  func wait() async throws {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      started.yield(())
    }
  }

  func failWithCancellation() {
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
}

private struct SuspendedUnbindDevice: DeviceRegistrationService {
  let gate: AccountUnbindGate
  let calls: LockIsolated<[String]>

  func installationDeviceID() async throws -> String { return "test-device" }
  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    return DeviceAuthorization(
      deviceID: "test-device",
      bearerToken: "test-token"
    )
  }
  func authorization() async throws -> DeviceAuthorization? { return nil }
  func linkDeviceToCurrentUser() async throws { calls.withValue { $0.append("bind") } }
  func unbindCurrentUser() async throws {
    calls.withValue { $0.append("unbind") }
    try await gate.wait()
  }
  func recoverBoundDevice() async throws { calls.withValue { $0.append("recover") } }
}

private enum DeviceUnbindTestError: Error {
  case unavailable
}

private extension AnalyticsUseCase {
  /// 호출을 기록하는 대역. 분석 호출을 검증하지 않는 계정 흐름 테스트에도 명시적으로 주입한다.
  static func recording(_ calls: LockIsolated<[AnalyticsCall]> = .init([])) -> Self {
    AnalyticsUseCase(
      registerBaseProperties: {},
      identify: { userID, method in calls.withValue { $0.append(.identify(userID, method)) } },
      track: { event in calls.withValue { $0.append(.track(event)) } },
      reset: { calls.withValue { $0.append(.reset) } }
    )
  }
}

/// 앱이 마이 화면에 입력 액션으로 보낸 계정 상태를 기대 상태에 반영한다.
private func syncProfileAccount(_ state: inout AppCoordinator.State) {
  guard case var .home(home) = state else { return }
  home.profileState.profile = home.authFlow.profile
  home.profileState.hasSession = home.authFlow.hasSession
  home.profileState.isLoading = home.authFlow.isLoading
  home.profileState.message = home.authFlow.message
  state = .home(home)
}

/// 설정 홈과 그 아래 계정 화면을 연 마이 목적지
private func settingsWithAccount(_ account: AccountSettingsFeature.State) -> SettingsHomeFeature.State {
  var settings = SettingsHomeFeature.State(hasSession: true)
  settings.destination = .account(account)
  return settings
}

/// 마이 화면이 설정 홈에 넘긴 계정 상태를 기대 상태에 반영한다.
private func syncSettingsScreen(_ state: inout AppCoordinator.State) {
  guard case var .home(home) = state, case var .settings(settings) = home.profileState.destination else { return }
  settings.profile = home.profileState.profile
  settings.hasSession = home.profileState.hasSession
  settings.isLoading = home.profileState.isLoading
  settings.message = home.profileState.message
  home.profileState.destination = .settings(settings)
  state = .home(home)
}

/// 설정 홈이 계정 화면에 넘긴 계정 상태를 기대 상태에 반영한다.
private func syncAccountScreen(_ state: inout AppCoordinator.State) {
  guard case var .home(home) = state,
        case var .settings(settings) = home.profileState.destination,
        case var .account(account) = settings.destination else { return }
  account.profile = home.authFlow.profile
  account.isLoading = home.authFlow.isLoading
  account.message = home.authFlow.message
  settings.destination = .account(account)
  home.profileState.destination = .settings(settings)
  state = .home(home)
}

extension DependencyValues {
  /// 이 테스트가 실행하는 홈 시작 효과에 필요한 의존성을 명시한다.
  mutating func useAppCoordinatorFestivalUseCases() {
    useServiceBackedFestivalUseCases()
    date = .constant(Date(timeIntervalSince1970: 0))
    festivalCatalogUseCase = AppCoordinatorCatalogUseCase()
    festivalPackUseCase = MockFestivalPackUseCase(cachedPacks: { [] })
    festivalImageUseCase = MockFestivalImageUseCase(
      imageURL: { value in return value.flatMap(URL.init(string:)) },
      startPrefetch: { _ in },
      stopPrefetch: {}
    )
    festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(
      activities: { [] },
      activityChanges: { AsyncStream { $0.finish() } }
    )
  }
}

private struct AppCoordinatorCatalogUseCase: FestivalCatalogUseCaseInterface {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalSelectionStore) private var selectionStore

  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    return try await catalogService.cachedFestivals()
  }

  func refreshFestivals() async throws -> [FestivalCatalogItem] {
    return try await catalogService.refresh()
  }

  func festivalDetail(for festivalID: String) async throws -> FestivalPackDocument {
    return try await catalogService.festivalDetail(for: festivalID)
  }

  func savedFestivalID() -> String? {
    return selectionStore.load()
  }

  func saveSelectedFestivalID(_ festivalID: String?) {
    selectionStore.save(festivalID)
  }
}
