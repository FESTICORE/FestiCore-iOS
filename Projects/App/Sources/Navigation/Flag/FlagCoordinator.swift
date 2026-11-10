//
//  FlagCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import TCAFlow

/// 깃발 탭의 화면 이동. 디렉토리를 루트로 두고 깃발 상세를 push한다.
@FlowCoordinator(
  screen: "FlagScreen",
  navigation: true
)
struct FlagCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<FlagScreen.State>]

    init() {
      routes = [.root(
        .directory(.init()),
        embedInNavigationView: true
      )]
    }

    /// 탭 루트의 깃발 디렉토리. 부모가 축제·계정 변경을 확인할 때 읽고 쓴다.
    var directory: FestivalFlagFeature.State {
      get { return routes.first?.screen.directory ?? FestivalFlagFeature.State() }
      set {
        guard !routes.isEmpty else { return }
        routes[0].screen = .directory(newValue)
      }
    }

    /// 깃발 상세가 열려 있는지. 열린 상세에 팩·내 일정·계정 변경을 알릴 때 쓴다.
    var isDetailOpen: Bool {
      return routes.contains { $0.screen.is(\.detail) }
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<FlagScreen>)
    case navigation(NavigationAction)
    case delegate(Delegate)
  }

  /// 부모가 요청하는 경로 변경. 상세 문맥은 축제 팩·내 일정을 가진 부모가 만든다.
  @CasePathable
  enum NavigationAction: Equatable {
    case showDetail(
      flagID: String,
      context: FestivalFlagDetailContext
    )
    case updateDetailContext(FestivalFlagDetailContext)
  }

  @CasePathable
  enum Delegate: Equatable {
    case detailRequested(flagID: String)
    case loginRequested
    case followLoginRequested
    case reportLoginRequested
    case termsAcceptanceRequested
  }

  func handleRoute(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case let .router(action):
      return handleRouterAction(
        state: &state,
        action: action
      )

    case let .navigation(action):
      return handleNavigationAction(
        state: &state,
        action: action
      )

    case .delegate:
      return .none
    }
  }
}

extension FlagCoordinator {
  private func handleRouterAction(
    state: inout State,
    action: IndexedRouterActionOf<FlagScreen>
  ) -> Effect<Action> {
    switch action {
    // MARK: 디렉토리
    case let .routeAction(
      id: _,
      action: .directory(.directory(.delegate(.detailRequested(flagID))))
    ):
      return .send(.delegate(.detailRequested(flagID: flagID)))

    case .routeAction(
      id: _,
      action: .directory(.directory(.delegate(.loginRequested)))
    ):
      return .send(.delegate(.loginRequested))

    case .routeAction(
      id: _,
      action: .directory(.directory(.delegate(.termsAcceptanceRequested)))
    ):
      return .send(.delegate(.termsAcceptanceRequested))

    // MARK: 깃발 상세
    case .routeAction(
      id: _,
      action: .detail(.delegate(.backRequested))
    ):
      state.routes.goBack()
      return .none

    case .routeAction(
      id: _,
      action: .detail(.delegate(.loginRequested))
    ):
      // 상세의 로그인 요청은 팔로우에서 온다(시안 S05 I).
      return .send(.delegate(.followLoginRequested))

    case .routeAction(
      id: _,
      action: .detail(.delegate(.reportLoginRequested))
    ):
      // 신고 로그인은 깃발 탭 기본 문맥(팔로우 문구) 대신 신고 문구를 띄운다.
      return .send(.delegate(.reportLoginRequested))

    case .routeAction(
      id: _,
      action: .detail(.delegate(.termsAcceptanceRequested))
    ):
      return .send(.delegate(.termsAcceptanceRequested))

    case let .routeAction(
      id: _,
      action: .detail(.delegate(.followChanged(
        flagID,
        isFollowing,
        followerCount
      )))
    ):
      return syncDirectoryFollow(
        state: state,
        result: FestivalFlagFollowResult(
          flagID: flagID,
          isFollowing: isFollowing,
          followerCount: followerCount
        )
      )

    default:
      return .none
    }
  }

  private func handleNavigationAction(
    state: inout State,
    action: NavigationAction
  ) -> Effect<Action> {
    switch action {
    case let .showDetail(
      flagID,
      context
    ):
      // 링크로 다른 깃발을 열면 쌓지 않고 바꾼다.
      state.routes.removeAll { $0.screen.is(\.detail) }
      state.routes.push(.detail(FestivalFlagDetailFeature.State(
        flagID: flagID,
        context: context
      )))
      return .none

    case let .updateDetailContext(context):
      let effects = state.routes.indices.compactMap { index -> Effect<Action>? in
        guard let detail = state.routes[index].screen.detail, detail.context != context else { return nil }
        return .send(.router(.routeAction(
          id: index,
          action: .detail(.view(.contextChanged(context)))
        )))
      }
      return .merge(effects)
    }
  }

  /// 상세에서 바꾼 팔로우를 디렉토리 카드에도 보인다. 기준 수는 디렉토리가 받은 서버 팔로워 수다.
  private func syncDirectoryFollow(
    state: State,
    result: FestivalFlagFollowResult
  ) -> Effect<Action> {
    let baseCount = state.directory.snapshot?.directoryFlags
      .first { $0.id == result.flagID }?
      .followerCount
    return .send(.router(.routeAction(
      id: 0,
      action: .directory(.directory(.followChangedElsewhere(
        result,
        baseCount: baseCount
      )))
    )))
  }
}

extension FlagCoordinator {
  @Reducer
  enum FlagScreen {
    case directory(FestivalFlagFeature)
    case detail(FestivalFlagDetailFeature)
  }
}

extension FlagCoordinator.FlagScreen.State: Equatable {}
