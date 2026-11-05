//
//  AppCoordinatorView.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestiCoreDesignKit
import SwiftUI

struct AppCoordinatorView: View {
  @Bindable var store: StoreOf<AppCoordinator>
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.backgroundNormal
        .ignoresSafeArea()

      switch store.state {
      case .splash:
        if let splashStore = store.scope(\.splash, action: \.scope.splash) {
          SplashView(store: splashStore)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }

      case .onboarding:
        if let onboardingStore = store.scope(\.onboarding, action: \.scope.onboarding) {
          OnboardingView(store: onboardingStore)
            .transition(.opacity)
        }

      case .home:
        if let homeStore = store.scope(\.home, action: \.scope.home) {
          MainTabView(store: homeStore)
            .transition(.asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .leading)
            ))
        }
      }
    }
    .animation(
      .spring(response: 0.52, dampingFraction: 0.94, blendDuration: 0.14),
      value: store.state.animationID
    )
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.send(.view(.foregrounded)) }
      if phase == .background { store.send(.view(.backgrounded)) }
    }
  }
}

#Preview {
  AppCoordinatorView(
    store: Store(initialState: AppCoordinator.State()) {
      AppCoordinator()
    }
  )
}
