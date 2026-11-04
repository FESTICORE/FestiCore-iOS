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
          liveBoardUnpublished: store.liveBoardUnpublished,
          isPackLoading: store.isPackLoading,
          liveBoardClockAnchorAt: store.liveBoardClockAnchorAt,
          liveBoardReceivedAt: store.liveBoardReceivedAt,
          hasSession: store.hasSession,
          hasUnreadNotifications: store.hasUnreadNotifications,
          sessionUserID: store.sessionUserID,
          mySetIDs: store.mySchedule?.setIDs ?? [],
          myScheduleUnavailable: store.myScheduleUnavailable,
          liveActivityState: store.liveActivityState,
          onLiveActivityTap: { send(.liveActivityTapped) },
          onLoginTap: { send(.loginTapped) },
          onNotificationTap: { send(.notificationTapped) },
          onBearerTap: store.bearerFlagID == nil ? nil : { send(.bearerTapped) },
          onRetryMySchedule: { send(.retryMySchedule) },
          onSwipeBack: { send(.backToFestivalList) }
        )
      } else {
        VStack(spacing: .zero) {
          FCTopBar(.back, title: "라이브 보드")
            .onBack { send(.backToFestivalList) }
          Group {
            if store.viewState == .loading {
              FestivalLiveBoardSkeletonView()
            } else {
              FCEmptyCard(
                icon: .music24,
                title: "페스티벌 정보를 찾을 수 없어요",
                message: "목록으로 돌아가 다시 선택해 주세요."
              )
            }
          }
          .padding(FestiCoreSpacing.paddingP16)
        }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .background(FestiCoreSemanticColor.backgroundNormal.color)
      }
    }
    .overlay(alignment: .bottom) {
      if let toast = store.toast {
        FestivalToastView(toast: toast, revision: store.toastRevision)
      }
    }
    .animation(.easeOut(duration: 0.2), value: store.toastRevision)
    .animation(.easeOut(duration: 0.2), value: store.toast)
    .task {
      send(.onAppear)
      send(.liveActivityOnAppear)
      send(.liveBoardOnAppear)
    }
    .onDisappear { send(.liveBoardOnDisappear) }
    .onChange(of: scenePhase) { _, phase in
      send(.foregroundChanged(phase == .active))
      if phase == .background { send(.backgrounded) }
    }
  }
}
