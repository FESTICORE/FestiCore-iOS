//
//  HomeFeatureTests.swift
//  Home
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import Testing
@testable import Home

struct HomeFeatureTests {
  @MainActor
  @Test func configurationStatusChanges() async {
    let store = TestStore(initialState: HomeFeature.State(configurationIsAvailable: false)) {
      HomeFeature()
    }

    await store.send(.configurationStatusChanged(true)) {
      $0.configurationIsAvailable = true
    }
  }
}
