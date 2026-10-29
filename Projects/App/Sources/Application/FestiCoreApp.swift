//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

import FeatureAssembly

@main
struct FestiCoreApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
      } withDependencies: {
        $0.continuousClock = ContinuousClock()
      }

      AppCoordinatorView(store: store)
        .onOpenURL { url in
          FeatureOAuthURLHandler.handle(url)
        }
    }
  }
}
