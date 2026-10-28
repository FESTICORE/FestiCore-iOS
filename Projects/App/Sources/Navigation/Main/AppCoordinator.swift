//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import Foundation

@Reducer
struct AppCoordinator {
  @ObservableState
  enum State: Equatable {
    case splash(SplashFeature.State)
    case home(HomeFeature.State)

    init() {
      self = .splash(SplashFeature.State())
    }

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
  }

  @CasePathable
  enum InnerAction {
    case completeHomeTransition
  }

  @CasePathable
  enum ScopeAction {
    case splash(SplashFeature.Action)
    case home(HomeFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(viewAction)

      case let .inner(innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case let .scope(scopeAction):
        return handleScopeAction(state: &state, action: scopeAction)
      }
    }
    .ifCaseLet(\.splash, action: \.scope.splash) {
      SplashFeature()
    }
    .ifCaseLet(\.home, action: \.scope.home) {
      HomeFeature()
    }
  }
}

private extension AppCoordinator {
  func handleViewAction(_ action: View) -> Effect<Action> {
    switch action {
    case .presentHome:
      return .send(.inner(.completeHomeTransition))
    }
  }

  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .completeHomeTransition:
      state = .home(.init())
      return .none
    }
  }

  func handleScopeAction(
    state: inout State,
    action: ScopeAction
  ) -> Effect<Action> {
    switch (action, state) {
    case (.splash(.delegate(.presentHome)), .splash):
      return .send(.view(.presentHome))
    default:
      return .none
    }
  }
}
