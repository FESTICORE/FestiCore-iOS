import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: FestivalFeature.self)
public struct FestivalLiveBoardRouteView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable public var store: StoreOf<FestivalFeature>

  public init(store: StoreOf<FestivalFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if let festival = store.selectedFestival {
        FestivalLiveBoardScreen(
          festival: festival,
          pack: store.selectedPack,
          liveBoard: store.liveBoard,
          liveBoardUnavailable: store.liveBoardUnavailable,
          liveBoardReceivedAt: store.liveBoardReceivedAt,
          hasSession: store.hasSession,
          sessionUserID: store.sessionUserID,
          mySetIDs: store.mySchedule?.setIDs ?? [],
          liveActivityState: store.liveActivityState,
          onLiveActivityTap: { send(.liveActivityTapped) },
          onLoginTap: { send(.loginTapped) },
          onSwipeBack: { send(.backToFestivalList) }
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
      send(.liveBoardOnAppear)
    }
    .onDisappear { send(.liveBoardOnDisappear) }
    .onChange(of: scenePhase) { _, phase in
      send(.foregroundChanged(phase == .active))
    }
  }
}
