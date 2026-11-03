import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: FestivalFeature.self)
public struct FestivalView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @Bindable public var store: StoreOf<FestivalFeature>

  public init(store: StoreOf<FestivalFeature>) {
    self.store = store
  }

  public var body: some View {
    festivalList
    .overlay(alignment: .bottom) { toast }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
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
    FestivalListView(
      userID: store.bookedUserID,
      recentSearches: store.recentSearches,
      festivals: store.festivals,
      bookedFestivalIDs: store.bookedFestivalIDs,
      packDownloads: store.packDownloads,
      imageRevision: store.imageRevision,
      isLoading: store.festivals.isEmpty && store.viewState == .loading,
      hasCatalogFailure: store.catalogCacheReadFailed || store.catalogRefreshFailed,
      offlineMessage: offlineMessage,
      imageURL: imageURL,
      onSelect: { send(.selectFestival($0)) },
      onToggleBooked: { send(.toggleBookedFestival($0)) },
      onDownloadPack: { send(.downloadPack($0)) },
      onTicketLink: { festival in
        if let url = festival.ticketURL {
          openURL(url)
        } else {
          send(.ticketLinkMissing)
        }
      },
      onRefresh: { send(.refreshRequested) },
      onRecentSearchSubmitted: { send(.recentSearchSubmitted($0)) },
      onRecentSearchRemoved: { send(.recentSearchRemoved($0)) },
      onRecentSearchesCleared: { send(.recentSearchesCleared) }
    )
  }

  var toast: some View {
    ZStack {
      if let toast = store.toast {
        FestivalToastView(toast: toast, revision: store.toastRevision)
      }
    }
    .animation(.easeOut(duration: 0.2), value: store.toastRevision)
  }

  func imageURL(_ value: String?) -> URL? {
    store.state.imageURL(for: value)
  }

  var offlineMessage: String? {
    if store.catalogCacheReadFailed {
      return "저장된 페스티벌 목록을 읽지 못했습니다 · 연결 후 다시 시도해 주세요"
    }
    if store.catalogRefreshFailed {
      return store.festivals.isEmpty
        ? "페스티벌 목록을 불러오지 못했습니다 · 다시 시도해 주세요"
        : "최신 페스티벌 목록을 불러오지 못했습니다 · 저장된 목록을 표시합니다"
    }
    return nil
  }
}
