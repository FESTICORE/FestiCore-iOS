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
  struct State: Equatable {
    var screen: AppScreen.State
    var configurationIsAvailable: Bool

    init() {
      self.init(configurationIsAvailable: AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:]) != nil)
    }

    init(configurationIsAvailable: Bool) {
      self.configurationIsAvailable = configurationIsAvailable
      screen = .splash(SplashFeature.State())
    }
  }

  @CasePathable
  enum Action {
    case screen(AppScreen.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(\.screen, action: \.screen) {
      Reduce<AppScreen.State, AppScreen.Action> { _, _ in .none }
        .ifCaseLet(\.splash, action: \.splash) {
          SplashFeature()
        }
        .ifCaseLet(\.home, action: \.home) {
          HomeFeature()
        }
    }
    Reduce { state, action in
      if case .screen(.splash(.delegate(.presentHome))) = action {
        state.screen = .home(HomeFeature.State(configurationIsAvailable: state.configurationIsAvailable))
      }
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
