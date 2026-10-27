//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Testing
import TCAFlow
@testable import FestiCore

struct AppCoordinatorTests {
  @Test(arguments: [true, false])
  func startsAtHomeWithConfigurationState(configurationIsAvailable: Bool) {
    let state = AppCoordinator.State(configurationIsAvailable: configurationIsAvailable)

    #expect(state.routes == [
      .root(.home(.init(configurationIsAvailable: configurationIsAvailable)), embedInNavigationView: true)
    ])
  }
}
