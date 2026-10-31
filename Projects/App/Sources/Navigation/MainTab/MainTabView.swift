//
//  MainTabView.swift
//  FestiCore
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestiCoreDesignKit
import SwiftUI

/// Figma 커스텀 탭바(`FCTabBar`)로 탭을 바꾸는 메인 화면
struct MainTabView: View {
  @Bindable var store: StoreOf<MainTabCoordinator>

  var body: some View {
    tabContent
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .safeAreaInset(edge: .bottom, spacing: .zero) {
        if store.shouldReserveTabBarSpace {
          FCTabBar(
            selection: Binding(
              get: { store.selectedTab },
              set: { store.send(.tabTapped($0)) }
            )
          )
          .opacity(store.shouldHideTabBar ? 0 : 1)
          .allowsHitTesting(!store.shouldHideTabBar)
        }
      }
      .background(FestiCoreSemanticColor.backgroundNormal.color)
      .overlay {
        if store.selectedTab == .timetable, store.timetableState.selectedSetID != nil {
          timetableView.modalOverlay
        } else if store.selectedTab == .my, store.profileState.isAccountPresented {
          profileView.modalOverlay
        }
      }
      .overlay {
        // 확인 팝업은 시트 위층의 고정 호스트에서 넣고 빼야 닫힘 애니메이션이 잘리지 않는다.
        if store.selectedTab == .my {
          profileView.dialogOverlay
        }
      }
  }
}

private extension MainTabView {
  /// 선택한 탭의 화면만 만든다. 탭 상태는 스토어에 남아 있어 다시 돌아와도 유지된다.
  @ViewBuilder
  var tabContent: some View {
    switch store.selectedTab {
    case .live:
      FestivalCoordinatorView(
        store: store.scope(
          state: \.festivalState,
          action: \.festival
        )
      )

    case .timetable:
      timetableView

    case .flag:
      FestivalFlagView(
        store: store.scope(state: \.flagState, action: \.flag)
      )

    case .my:
      profileView
    }
  }

  var profileView: ProfileView {
    ProfileView(
      store: store.scope(state: \.profileState, action: \.profile),
      profile: store.authFlow.profile,
      hasSession: store.authFlow.hasSession,
      isLoading: store.authFlow.isLoading,
      message: store.authFlow.message
    )
  }

  var timetableView: TimetableView {
    TimetableView(
      store: store.scope(state: \.timetableState, action: \.timetable)
    )
  }
}

#Preview {
  MainTabView(
    store: Store(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    }
  )
}
