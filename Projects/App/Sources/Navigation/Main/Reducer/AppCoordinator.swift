//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreStorageInterface
import Foundation

@Reducer
struct AppCoordinator {
  @CasePathable
  @dynamicMemberLookup
  @ObservableState
  enum State: Equatable {
    case splash(SplashFeature.State)
    case onboarding(OnboardingFeature.State)
    case home(MainTabCoordinator.State)

    init() { self = .splash(SplashFeature.State()) }
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
    case backgrounded
    case openWidgetRoute(WidgetDeepLink)
    /// 로그인 시트의 로그인 요청(`LoginDelegate.signInRequested`)도 여기서 시트 상태를 확인한다.
    case startLogin(OAuthProvider)
    case dismissFlow
    case retryProfile
    case resolveMigration(Bool)
  }

  @CasePathable
  enum InnerAction {
    case firstInstallStatus(Bool)
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
    case onboarding(OnboardingFeature.Action)
    case home(MainTabCoordinator.Action)
  }

  @Dependency(\.authUseCase) var authUseCase
  @Dependency(\.authService) var authService
  @Dependency(\.deviceRegistrationService) var deviceRegistrationService
  @Dependency(\.festivalLiveActivityUseCase) var festivalLiveActivityUseCase
  @Dependency(\.festivalWidgetClient) var festivalWidgetClient
  @Dependency(\.date) var date
  @Dependency(\.festivalLibraryUseCase) var festivalLibraryUseCase
  @Dependency(\.authSessionExpiryClient) var authSessionExpiryClient
  @Dependency(\.analyticsUseCase) var analyticsUseCase
  @Dependency(\.firstInstallOnboardingStore) var firstInstallOnboardingStore

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      let previousSession: MainTabCoordinator.AuthInputs.Session?
      if case let .home(home) = state {
        previousSession = home.authInputs.session
      } else {
        previousSession = nil
      }
      let effect: Effect<Action>
      switch action {
      case let .view(viewAction):
        effect = handleViewAction(
          state: &state,
          action: viewAction
        )
      case let .inner(innerAction):
        effect = handleInnerAction(
          state: &state,
          action: innerAction
        )
      case let .scope(scopeAction):
        effect = handleScopeAction(
          state: &state,
          action: scopeAction
        )
      }
      if let previousSession, case var .home(home) = state {
        let currentSession = home.authInputs.session
        if previousSession.userID != nil && previousSession.userID != currentSession.userID {
          clearAccountDisplayData(&home)
        } else if !previousSession.hasSession && currentSession.hasSession {
          home.tabs.flag.clearAccountData()
        }
        state = .home(home)
      }
      return effect
    }
    .ifCaseLet(
      \.splash,
      action: \.scope.splash) { SplashFeature() }
    .ifCaseLet(
      \.onboarding,
      action: \.scope.onboarding) { OnboardingFeature() }
    .ifCaseLet(
      \.home,
      action: \.scope.home) { MainTabCoordinator() }
    .onChange(of: \.self) { previous, current in
      return authInputsChangeEffect(
        previous: previous,
        current: current
      )
    }
    .onChange(of: \.activeWidgetSnapshotContent) { _, state in
      return saveWidgetSnapshot(state: state)
    }
  }

  private func authInputsChangeEffect(
    previous: State,
    current: State
  ) -> Effect<Action> {
    let previousInputs = previous.authInputs
    guard let currentInputs = current.authInputs,
          previousInputs != currentInputs else { return .none }
    return .send(.scope(.home(.authInputsChanged(
      previous: previousInputs,
      current: currentInputs
    ))))
  }

  private func saveWidgetSnapshot(state: State) -> Effect<Action> {
    // 계정이 없어지면 공개 팩만 남기고 홈을 이탈하면 공유 파일을 비운다.
    let snapshot = state.activeWidgetSnapshotContent?.withUpdatedAt(date.now)
    return .run { _ in await festivalWidgetClient.save(snapshot) }
      .cancellable(
        id: CancelID.widgetSnapshot,
        cancelInFlight: true
      )
  }
}
