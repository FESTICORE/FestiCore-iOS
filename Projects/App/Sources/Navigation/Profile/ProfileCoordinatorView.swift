import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct ProfileCoordinatorView: View {
  @Bindable var store: StoreOf<ProfileCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(
      state: \.profileRoutes,
      action: \.router
    )) { screen in
      switch screen.case {
      case let .profile(profileStore):
        ProfileView(store: profileStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .packDetail(detailStore):
        PackDetailView(store: detailStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .account(accountStore):
        AccountSettingsView(store: accountStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .legalDocument(webStore):
        WebView(store: webStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .lockScreen(lockScreenStore):
        LockScreenSettingsView(store: lockScreenStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .noticeList(noticeStore):
        NoticeListView(store: noticeStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .noticeDetail(detailStore):
        NoticeDetailView(store: detailStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case let .notifications(notificationStore):
        NotificationSettingsView(store: notificationStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      }
    }
  }
}
