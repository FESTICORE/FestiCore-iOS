//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

import FeatureAssembly
import ServiceAssembly

@main
struct FestiCoreApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      if TestContext.current == nil {
        let store = Store(initialState: AppCoordinator.State()) {
          AppCoordinator()
        } withDependencies: {
          ServiceDependencyAssembly.register(into: &$0)
        }

        AppCoordinatorView(store: store)
          .onOpenURL { url in
            FeatureOAuthURLHandler.handle(url)
          }
      }
    }
  }
}
