import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

@ViewAction(for: FestivalFeature.self)
public struct FestivalLiveBoardRouteView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable public var store: StoreOf<FestivalFeature>

  public init(store: StoreOf<FestivalFeature>) {
    self.store = store
  }

  public var body: some View {
    return Group {
      if store.selectedFestival != nil {
        FestivalLiveBoardScreen(store: store)
      } else {
        VStack(spacing: .zero) {
          FCTopBar(
            .back,
            title: "라이브 보드"
          )
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
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
          )
          .background(FestiCoreSemanticColor.backgroundNormal.color)
      }
    }
    .overlay(alignment: .top) {
      if let toast = store.toast {
        FestivalToastView(
          toast: toast,
          revision: store.toastRevision
        )
      }
    }
    .animation(
      .easeOut(duration: 0.2),
      value: store.toastRevision
    )
    .animation(
      .easeOut(duration: 0.2),
      value: store.toast
    )
    .fcModal($store.scope(
      state: \.festivalSwitcher,
      action: \.festivalSwitcher
    )) { switcherStore in
      FestivalSwitcherView(store: switcherStore)
    }
    .fcModal($store.scope(
      state: \.crewGather,
      action: \.crewGather
    )) { gatherStore in
      FestivalCrewGatherView(store: gatherStore)
    }
    .fcModal($store.scope(
      state: \.crewCreate,
      action: \.crewCreate
    )) { crewStore in
      FestivalCrewCreateView(store: crewStore)
    }
    .fcAlert($store.scope(
      state: \.alert,
      action: \.alert
    ))
    .fcAlert($store.scope(
      state: \.followGuideAlert,
      action: \.followGuideAlert
    ))
    .task {
      send(.onAppear)
      send(.liveActivityOnAppear)
      send(.liveBoardOnAppear)
      send(.onlineDetailOnAppear)
    }
    .onDisappear { send(.liveBoardOnDisappear) }
    .onChange(of: scenePhase) { _, phase in
      send(.foregroundChanged(phase == .active))
    }
  }
}
