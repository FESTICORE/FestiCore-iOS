import ComposableArchitecture
import SwiftUI

@ViewAction(for: HomeFeature.self)
public struct HomeView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable public var store: StoreOf<HomeFeature>

  public init(store: StoreOf<HomeFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 24) {
        status
        festivalList
        festivalDetail
      }
      .padding(20)
    }
    .navigationTitle("FestiCore")
    .refreshable { send(.refreshRequested) }
    .task {
      send(.onAppear)
      send(.liveActivityOnAppear)
    }
    .onChange(of: scenePhase) { _, phase in
      send(.foregroundChanged(phase == .active))
    }
  }

  private var festivalList: some View {
    HomeFestivalListView(
      festivals: store.festivals,
      selectedFestivalID: store.selectedFestivalID,
      imageRevision: store.imageRevision,
      imageURL: imageURL,
      onSelect: { send(.selectFestival($0)) }
    )
  }

  @ViewBuilder
  private var festivalDetail: some View {
    if let festival = store.selectedFestival {
      HomeFestivalDetailView(
        festival: festival,
        pack: store.selectedPack,
        imageRevision: store.imageRevision,
        imageURL: imageURL,
        liveActivityState: store.liveActivityState,
        onLiveActivityTap: { send(.liveActivityTapped) }
      )
    }
  }

  private func imageURL(_ value: String?) -> URL? {
    store.state.imageURL(for: value)
  }

  private var status: some View {
    HStack(spacing: 8) {
      Image(systemName: store.connection == .live ? "wifi" : "square.and.arrow.down")
      Text(statusText)
        .font(.subheadline)
      Spacer()
    }
    .foregroundStyle(store.connection == .offline ? Color.orange : Color.secondary)
    .accessibilityLabel(statusText)
  }

  private var statusText: String {
    if store.cacheReadFailed {
      return store.selectedPack == nil
        ? "저장된 정보를 읽지 못했습니다 · 연결 후 다시 시도해 주세요"
        : "일부 저장 정보를 읽지 못했습니다 · 표시 중인 팩은 사용할 수 있습니다"
    }
    return switch store.connection {
    case .loading: "저장된 축제를 불러오는 중"
    case .cached: "저장된 정보 표시 중 · 연결되면 갱신됩니다"
    case .connecting: "최신 정보를 확인하는 중"
    case .reconnecting:
      store.selectedPack == nil
        ? "연결을 다시 시도하는 중 · 저장된 상세 정보가 없습니다"
        : "연결을 다시 시도하는 중 · 저장된 정보를 표시합니다"
    case .live: "최신 정보로 갱신됨"
    case .offline:
      store.selectedPack == nil
        ? "오프라인 · 저장된 상세 정보가 없습니다"
        : "오프라인 · 저장된 정보를 표시합니다"
    case .unavailable: "이 축제의 오프라인 팩은 아직 없습니다"
    }
  }

}
