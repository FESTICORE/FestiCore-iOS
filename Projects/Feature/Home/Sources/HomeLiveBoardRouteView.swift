import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: HomeFeature.self)
public struct HomeLiveBoardRouteView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable public var store: StoreOf<HomeFeature>

  public init(store: StoreOf<HomeFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if let festival = store.selectedFestival {
        HomeLiveBoardScreen(
          festival: festival,
          pack: store.selectedPack,
          imageRevision: store.imageRevision,
          imageURL: { store.state.imageURL(for: $0) },
          liveActivityState: store.liveActivityState,
          onLiveActivityTap: { send(.liveActivityTapped) },
          onBack: { send(.backToFestivalList) }
        )
      } else {
        ProgressView("페스티벌 정보를 불러오는 중")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(FestiCoreSemanticColor.backgroundNormal.color)
      }
    }
    .task {
      send(.onAppear)
      send(.liveActivityOnAppear)
    }
    .onChange(of: scenePhase) { _, phase in
      send(.foregroundChanged(phase == .active))
    }
  }
}
