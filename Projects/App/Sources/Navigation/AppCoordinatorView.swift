//
//  AppCoordinatorView.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct AppCoordinatorView: View {
  @Bindable var store: StoreOf<AppCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(\.routes, action: \.router)) { screen in
      switch screen.case {
      case .home(let homeStore):
        FestiCoreHomeView(store: homeStore)
      }
    }
  }
}
