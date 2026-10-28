//
//  AppCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import Foundation
import TCAFlow

@FlowCoordinator(screen: "AppScreen", navigation: true)
struct AppCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<AppScreen.State>]
    var configurationIsAvailable: Bool

    init() {
      self.init(configurationIsAvailable: AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:]) != nil)
    }

    init(configurationIsAvailable: Bool) {
      self.configurationIsAvailable = configurationIsAvailable
      routes = [
        .root(
          .splash(SplashFeature.State())
        )
      ]
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<AppScreen>)
  }

  func handleRoute(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .router(.routeAction(id: _, action: .splash(.delegate(.presentHome)))):
      state.routes = [
        .root(
          .home(HomeFeature.State(configurationIsAvailable: state.configurationIsAvailable)),
          embedInNavigationView: true
        )
      ]
      return .none

    default:
      return .none
    }
  }
}

extension AppCoordinator {
  @Reducer
  enum AppScreen {
    case splash(SplashFeature)
    case home(HomeFeature)
  }
}

extension AppCoordinator.AppScreen.State: Equatable {}
