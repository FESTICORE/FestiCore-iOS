import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct HomeCoordinatorView: View {
  @Bindable var store: StoreOf<HomeCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(\.routes, action: \.router)) { screen in
      switch screen.case {
      case let .home(homeStore):
        HomeView(store: homeStore)
      }
    }
  }
}
