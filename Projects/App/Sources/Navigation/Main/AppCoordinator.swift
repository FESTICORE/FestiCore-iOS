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
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreStorageInterface
import FestiCoreUtility
import Foundation
import OSLog

@Reducer
struct AppCoordinator {
  @Dependency(\.festivalWidgetClient) var festivalWidgetClient
  @Dependency(\.date) var date
  @Dependency(\.authSessionExpiryClient) var authSessionExpiryClient
  @Dependency(\.firstInstallOnboardingStore) var firstInstallOnboardingStore
  @Dependency(\.authService) var authService

  enum CancelID { case sessionExpiry, widgetSnapshot }

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

    /// 홈 위에 S14 A 로그인 첫 진입 화면이 떠 있다. 닫힐 때까지 세션 재확인과 대기 딥링크를 미룬다.
    var isLaunchLoginPresented: Bool {
      guard case let .home(home) = self else { return false }
      return home.authFlow.presentation == .launchLogin
    }

    /// 첫 진입 화면이나 그 화면에서 이어진 가입·기수 설정이 메인 탭을 덮고 있다. 걷힐 때까지 대기 딥링크를 미룬다.
    var isMainTabCovered: Bool {
      guard case let .home(home) = self else { return false }
      return home.authFlow.coversMainTab
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
  }

  @CasePathable
  enum InnerAction {
    case firstInstallStatus(Bool)
    /// 세션을 복원한 결과. 로그아웃 상태면 홈 위에 로그인 첫 진입 화면을 띄운다.
    case sessionChecked(isLoggedIn: Bool)
    case completeHomeTransition
  }

  @CasePathable
  enum ScopeAction {
    case splash(SplashFeature.Action)
    case onboarding(OnboardingFeature.Action)
    case home(MainTabCoordinator.Action)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )
      case let .inner(innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )
      case let .scope(scopeAction):
        return handleScopeAction(
          state: &state,
          action: scopeAction
        )
      }
    }
    .ifCaseLet(\.splash, action: \.scope.splash) { SplashFeature() }
    .ifCaseLet(\.onboarding, action: \.scope.onboarding) { OnboardingFeature() }
    .ifCaseLet(
      \.home,
      action: \.scope.home
    ) {
      MainTabCoordinator()
    }
    .onChange(of: \.self) { previous, state in
      return authInputsChanged(
        previous: previous,
        current: state
      )
    }
    .onChange(of: \.isLaunchLoginPresented) { wasPresented, state in
      // 건너뛰거나 로그인해 첫 진입 화면이 닫히면 홈에서 세션을 확인하고 대기 딥링크를 꺼낸다.
      guard wasPresented, !state.isLaunchLoginPresented else { return .none }
      return .merge(
        .send(.scope(.home(.session(.view(.foregrounded))))),
        .send(.view(.deeplinkReceived))
      )
    }
    .onChange(of: \.isMainTabCovered) { wasCovered, state in
      // 가입·기수 설정을 마쳐 메인 탭이 보이면 그때 대기 딥링크를 꺼낸다.
      guard wasCovered, !state.isMainTabCovered else { return .none }
      return .send(.view(.deeplinkReceived))
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

// MARK: - 앱 생명주기·딥링크

extension AppCoordinator {
  /// 앞·뒤 전환과 딥링크를 홈에 전달한다. 홈이 아니면 무시한다.
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .presentHome:
      guard case .splash = state else { return .none }
      return .run { send in
        // 이전 실행에서 남은 개인 Widget 파일은 세션 확인 전에 지운다.
        await festivalWidgetClient.save(nil)
        do {
          await send(.inner(.firstInstallStatus(try firstInstallOnboardingStore.hasCompleted())))
        } catch {
          FestiCoreLogger.error(
            "첫 설치 기록을 확인할 수 없음: \(error.localizedDescription)",
            category: .app
          )
          await send(.inner(.firstInstallStatus(true)))
        }
      }

    case .foregrounded:
      guard case .home = state else { return .none }
      // 축제 화면이 다시 읽기 전에 세션이 확인한 계정을 비우고 새 세대를 연다.
      return .merge(
        .send(.scope(.home(.session(.view(.foregrounded))))),
        .send(.scope(.home(.festival(.foregrounded))))
      )

    case .backgrounded:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.festival(.backgrounded))))

    case .remoteContentChanged:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.festival(.remoteContentChanged))))

    case let .openDeeplink(deeplink):
      guard case .home = state else { return .none }
      return .send(.scope(.home(.openDeeplink(deeplink))))

    case .deeplinkReceived:
      // 홈 전환 전이면 대기 값을 남겨 두고, 홈에 들어갈 때 다시 꺼낸다.
      // 로그인 첫 진입 화면이 떠 있으면 닫은 뒤에 꺼낸다.
      guard case .home = state,
            !state.isMainTabCovered,
            let deeplink = AppDeeplinkBridge.consumePending() else { return .none }
      return .send(.view(.openDeeplink(deeplink)))
    }
  }
}
