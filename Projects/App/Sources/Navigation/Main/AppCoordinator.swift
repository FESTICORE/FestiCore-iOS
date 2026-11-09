//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import CoreAssembly
import FeatureAssembly
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestiCoreStorageInterface
import FestiCoreUtility
import Foundation
import OSLog

@Reducer
struct AppCoordinator {
  @Dependency(\.authUseCase) var authUseCase
  @Dependency(\.authService) var authService
  @Dependency(\.deviceRegistrationService) var deviceRegistrationService
  @Dependency(\.festivalLiveActivityUseCase) var festivalLiveActivityUseCase
  @Dependency(\.festivalWidgetClient) var festivalWidgetClient
  @Dependency(\.date) var date
  @Dependency(\.festivalBookedStore) var bookedStore
  @Dependency(\.authSessionExpiryClient) var authSessionExpiryClient
  @Dependency(\.analyticsUseCase) var analyticsUseCase
  @Dependency(\.firstInstallOnboardingStore) var firstInstallOnboardingStore

  enum CancelID { case sessionExpiry, accountOperation, widgetSnapshot }

  /// 약관 상세 기준 주소. 탭 코디네이터와 가입 화면이 같은 값을 쓴다.
  private let legalBaseURL: URL?

  init(legalBaseURL: URL? = AppCoordinatorView.legalBaseURL(
    host: Bundle.main.object(forInfoDictionaryKey: "FestiCoreAPIHost") as? String
  )) {
    self.legalBaseURL = legalBaseURL
  }

  @ObservableState
  enum State: Equatable {
    case splash(SplashFeature.State)
    case onboarding(OnboardingFeature.State)
    case home(MainTabCoordinator.State)

    init() { self = .splash(SplashFeature.State()) }

    var animationID: String {
      switch self {
      case .splash: "splash"
      case .onboarding: "onboarding"
      case .home: "home"
      }
    }

    /// 선택한 공개 팩은 로그인 없이 공유하고 개인 일정은 상위 세션이 확인된 동안만 포함한다.
    var activeWidgetSnapshotContent: FestivalWidgetSnapshot? {
      guard case let .home(home) = self,
            let screen = home.festivalState.routes.last(where: {
              $0.screen.is(\.festivalList) || $0.screen.is(\.liveBoard)
            })?.screen else { return nil }
      var festival: FestivalFeature.State
      switch screen {
      case let .festivalList(list): festival = list
      case let .liveBoard(board): festival = board
      case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist: return nil
      }
      festival.hasSession = home.authFlow.hasSession && festival.hasSession
      return festival.widgetSnapshotContent
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
    case backgrounded
    case remoteContentChanged
    /// 위젯·푸시 딥링크로 화면을 연다.
    case openDeeplink(FestiCoreDeeplink)
    /// 대기 저장소에 새 딥링크가 들어왔다. 홈이면 바로 꺼내 연다.
    case deeplinkReceived
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

    // MARK: 세션·프로필 결과

    case sessionRestored(
      generation: Int,
      userID: String?,
      isLoggedIn: Bool
    )
    case profileLoaded(
      generation: Int,
      Result<AuthProfile, ProfileFailure>
    )
    case profileUpdated(
      generation: Int,
      Result<AuthUser, ProfileFailure>
    )
    case myAccountFinished(
      generation: Int,
      operation: MyAccountOperation,
      result: Result<Void, ProfileFailure>
    )
    case loginCommitted(
      AuthLoginResult,
      generation: Int,
      committed: Bool
    )
    case staleLoginDiscarded
  }

  @CasePathable
  enum ScopeAction {
    case splash(SplashFeature.Action)
    case onboarding(OnboardingFeature.Action)
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
        return
      }
      guard let network = error as? FestiCoreNetworkError else {
        self = .unavailable
        return
      }

      switch network {
      case let .transport(transport):
        switch transport {
        case .notConnected, .timedOut:
          self = .offline
        case .cancelled, .unknown:
          self = .unavailable
        }
      case let .response(response):
        if response.httpStatus == 401 {
          self = .unauthenticated
        } else if response.httpStatus == 422 && response.code == "TERMS_VERSION_OUTDATED" {
          self = .termsOutdated
        } else {
          self = .unavailable
        }
      case .request, .decoding:
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
      let previousSession = session(in: state)
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
      reconcileAccountDisplayData(
        previousSession: previousSession,
        state: &state
      )
      return effect
    }
    .ifCaseLet(\.splash, action: \.scope.splash) { SplashFeature() }
    .ifCaseLet(\.onboarding, action: \.scope.onboarding) { OnboardingFeature() }
    .ifCaseLet(\.home, action: \.scope.home) { MainTabCoordinator(legalBaseURL: legalBaseURL) }
    .onChange(of: \.self) { previous, state in
      return authInputsChanged(
        previous: previous,
        current: state
      )
    }
    .onChange(of: \.activeWidgetSnapshotContent) { _, state in
      // 계정이 없어지면 공개 팩만 남기고 홈을 이탈하면 공유 파일을 비운다.
      return persistWidgetSnapshot(
        from: state
      )
    }
  }
}

private extension AppCoordinator {
  func session(in state: State) -> MainTabCoordinator.AuthInputs.Session? {
    guard case let .home(home) = state else { return nil }
    return home.authInputs.session
  }

  func reconcileAccountDisplayData(
    previousSession: MainTabCoordinator.AuthInputs.Session?,
    state: inout State
  ) {
    guard let previousSession, case var .home(home) = state else { return }
    let currentSession = home.authInputs.session
    if previousSession.userID != nil && previousSession.userID != currentSession.userID {
      clearAccountDisplayData(&home)
    } else if !previousSession.hasSession && currentSession.hasSession {
      home.flagState.clearAccountData()
    }
    state = .home(home)
  }

  func authInputsChanged(
    previous: State,
    current: State
  ) -> Effect<Action> {
    guard case let .home(home) = current else { return .none }
    let previousInputs: MainTabCoordinator.AuthInputs?
    if case let .home(previousHome) = previous {
      previousInputs = previousHome.authInputs
    } else {
      previousInputs = nil
    }
    let currentInputs = home.authInputs
    guard previousInputs != currentInputs else { return .none }
    return .send(.scope(.home(.authInputsChanged(
      previous: previousInputs,
      current: currentInputs
    ))))
  }

  func persistWidgetSnapshot(from state: State) -> Effect<Action> {
    let snapshot = state.activeWidgetSnapshotContent?.withUpdatedAt(date.now)
    return .run { _ in await festivalWidgetClient.save(snapshot) }
      .cancellable(
        id: CancelID.widgetSnapshot,
        cancelInFlight: true
      )
  }
}
