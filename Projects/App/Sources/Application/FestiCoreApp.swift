//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import FeatureAssembly
import ComposableArchitecture
import Dependencies
import ServiceAssembly

@main
struct FestiCoreApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  private let configuration: AppConfiguration?
  private let store: StoreOf<AppCoordinator>

  init() {
    let configuration = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
    self.configuration = configuration
    prepareDependencies {
      ServiceDependencyAssembly.register(into: &$0)
    }
    store = Store(initialState: AppCoordinator.State(configurationIsAvailable: configuration != nil)) {
      AppCoordinator()
    }
  }

  var body: some Scene {
    WindowGroup {
      AppCoordinatorView(store: store)
    }
  }
}
