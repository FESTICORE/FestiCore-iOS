//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Foundation
import Testing
import TCAFlow
@testable import FestiCore

struct AppCoordinatorTests {
  @Test func defaultStateUsesAppConfiguration() {
    let configurationIsAvailable = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:]) != nil
    #expect(AppCoordinator.State() == AppCoordinator.State(configurationIsAvailable: configurationIsAvailable))
  }

  @Test(arguments: [true, false])
  func startsAtSplashAndKeepsConfigurationState(configurationIsAvailable: Bool) {
    var state = AppCoordinator.State(configurationIsAvailable: configurationIsAvailable)

    #expect(state.configurationIsAvailable == configurationIsAvailable)
    #expect(state.routes == [
      .root(.splash(.init()))
    ])

    _ = AppCoordinator().handleRoute(
      state: &state,
      action: .router(.routeAction(id: 0, action: .splash(.delegate(.presentHome))))
    )

    #expect(state.routes == [
      .root(.home(.init(configurationIsAvailable: configurationIsAvailable)), embedInNavigationView: true)
    ])
  }
}
