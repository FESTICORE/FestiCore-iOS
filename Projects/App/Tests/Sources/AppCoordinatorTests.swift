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
  func startsAtHomeWithConfigurationState(configurationIsAvailable: Bool) {
    let state = AppCoordinator.State(configurationIsAvailable: configurationIsAvailable)

    #expect(state.routes == [
      .root(.home(.init(configurationIsAvailable: configurationIsAvailable)), embedInNavigationView: true)
    ])
  }
}
