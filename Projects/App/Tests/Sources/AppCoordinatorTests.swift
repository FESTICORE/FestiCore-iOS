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
  @Test func startsAtHomeWithConfigurationState() {
    let state = AppCoordinator.State(configurationIsAvailable: true)

    #expect(state.routes == [
      .root(.home(.init(configurationIsAvailable: true)), embedInNavigationView: true)
    ])
  }
}
