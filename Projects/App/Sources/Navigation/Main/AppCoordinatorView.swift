//
//  AppCoordinatorView.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import SwiftUI

struct AppCoordinatorView: View {
  @Bindable var store: StoreOf<AppCoordinator>

  var body: some View {
    SwitchStore(store.scope(state: \.screen, action: \.screen)) { state in
      switch state {
      case .splash:
        if let splashStore = store.scope(state: \.screen.splash, action: \.screen.splash) {
          SplashView(store: splashStore)
        }

      case .home:
        if let homeStore = store.scope(state: \.screen.home, action: \.screen.home) {
          FestiCoreHomeView(store: homeStore)
        }
      }
    }
  }
}
