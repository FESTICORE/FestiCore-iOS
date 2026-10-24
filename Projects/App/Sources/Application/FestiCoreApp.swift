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

  init() {
    prepareDependencies {
      ServiceDependencyAssembly.register(into: &$0)
    }
  }

  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
      }

      AppCoordinatorView(store: store)
    }
  }
}
