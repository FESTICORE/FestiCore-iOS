//
//  MainTabView.swift
//  FestiCore
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestiCoreDesignKit
import FestiCoreSharedUI
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
        if store.selectedTab == .timetable, store.timetableState.setDetail != nil {
          // 공연 상세 시트는 탭바까지 덮도록 탭을 그리는 이 화면에서 띄운다.
          Color.clear.fcModal($store.scope(state: \.timetableState.setDetail, action: \.timetable.scope.setDetail)) { detailStore in
            TimetableSetDetailView(store: detailStore)
          } accessory: { detailStore in
            TimetableScheduleToast(isVisible: detailStore.isScheduleToastVisible)
          }
        } else if store.selectedTab == .my, store.profileState.isAccountPresented {
          profileView.modalOverlay
        }
      }
      .overlay {
        // 확인 팝업은 시트 위 별도 층에 띄운다. 팝업 애니메이션이 계정 시트와 뒤 화면 배치에 번지지 않게 한다.
        if store.selectedTab == .my {
          Color.clear
            .fcAlert(
              $store.scope(state: \.profileState.destination?.alert, action: \.profile.destination.alert),
              dismissesOnDimTap: true
            )
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
    ProfileView(store: store.scope(state: \.profileState, action: \.profile))
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
