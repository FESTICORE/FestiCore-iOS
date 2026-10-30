import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct FestivalCoordinatorView: View {
  @Bindable var store: StoreOf<FestivalCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(\.routes, action: \.router)) { screen in
      switch screen.case {
      case let .festivalList(festivalStore):
        FestivalView(store: festivalStore)
      case let .liveBoard(liveBoardStore):
        FestivalLiveBoardRouteView(store: liveBoardStore)
          .swipeBackButtonHidden()
      }
    }
  }
}
