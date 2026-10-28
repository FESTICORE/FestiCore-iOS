//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

import FeatureAssembly
import ServiceAssembly

@main
struct FestiCoreApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
      } withDependencies: {
        ServiceDependencyAssembly.register(into: &$0)
      }

      AppCoordinatorView(store: store)
    }
  }
}
