//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import TCAFlow

@FlowCoordinator(screen: "AppScreen", navigation: true)
struct AppCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<AppScreen.State>]

    init(configurationIsAvailable: Bool) {
      routes = [
        .root(
          .home(HomeFeature.State(configurationIsAvailable: configurationIsAvailable)),
          embedInNavigationView: true
        )
      ]
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<AppScreen>)
  }

  func handleRoute(state: inout State, action: Action) -> Effect<Action> {
    .none
  }
}

extension AppCoordinator {
  @Reducer
  enum AppScreen {
    case home(HomeFeature)
  }
}

extension AppCoordinator.AppScreen.State: Equatable {}
