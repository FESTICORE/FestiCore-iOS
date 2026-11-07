import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: FestivalFeature.self)
public struct FestivalView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable public var store: StoreOf<FestivalFeature>

  public init(store: StoreOf<FestivalFeature>) {
    self.store = store
  }

  public var body: some View {
    return festivalList
    .overlay(alignment: .bottom) { toast }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(
      .hidden,
      for: .navigationBar
    )
    .task {
      send(.onAppear)
      send(.liveActivityOnAppear)
    }
    .onChange(of: scenePhase) { _, phase in
      send(.foregroundChanged(phase == .active))
    }
  }


}

private extension FestivalView {
  var festivalList: some View {
    return FestivalListView(store: store)
  }

  var toast: some View {
    return ZStack {
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
  }

}
