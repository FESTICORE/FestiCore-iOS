//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Foundation
import Testing

import ComposableArchitecture
@testable import FestiCore

struct AppCoordinatorTests {
  @Test func defaultStateUsesAppConfiguration() {
    let configurationIsAvailable = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:]) != nil
    #expect(AppCoordinator.State() == AppCoordinator.State(configurationIsAvailable: configurationIsAvailable))
  }

  @Test(arguments: [true, false])
  func startsAtSplashAndKeepsConfigurationState(configurationIsAvailable: Bool) async {
    let state = AppCoordinator.State(configurationIsAvailable: configurationIsAvailable)

    #expect(state.configurationIsAvailable == configurationIsAvailable)
    #expect(state.screen == .splash(.init()))

    let store = TestStore(initialState: state) {
      AppCoordinator()
    }
    await store.send(.screen(.splash(.delegate(.presentHome)))) {
      $0.screen = .home(.init(configurationIsAvailable: configurationIsAvailable))
    }

    #expect(store.state.screen == .home(.init(configurationIsAvailable: configurationIsAvailable)))
  }
}
