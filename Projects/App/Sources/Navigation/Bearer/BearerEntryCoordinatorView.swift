import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct BearerEntryCoordinatorView: View {
  @Bindable var store: StoreOf<BearerEntryCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(
      \.routes,
      action: \.router
    )) { screen in
      switch screen.case {
      case let .claim(claimStore):
        BearerClaimView(store: claimStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .profile(profileStore):
        BearerProfileView(store: profileStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .planPick(planStore):
        BearerPlanPickView(store: planStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .board(boardStore):
        BearerBoardView(store: boardStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      }
    }
  }
}
