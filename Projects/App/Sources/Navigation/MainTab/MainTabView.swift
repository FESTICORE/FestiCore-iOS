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
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity)
      .safeAreaInset(
        edge: .bottom,
        spacing: .zero) {
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
      .animation(
        .easeInOut(duration: 0.25),
        value: store.shouldReserveTabBarSpace
      )
      .animation(
        .easeInOut(duration: 0.25),
        value: store.shouldHideTabBar
      )
      .background(FestiCoreSemanticColor.backgroundNormal.color)
      .overlay {
        if store.selectedTab == .timetable, store.tabs.timetableFeature.setDetail != nil {
          // 공연 상세 시트는 탭바까지 덮도록 탭을 그리는 이 화면에서 띄운다.
          Color.clear.fcModal($store.scope(
            \.tabs.timetableFeature.setDetail,
            action: \.scopeAction.timetableCoordinator.timetable.scope.setDetail
          )) { detailStore in
            TimetableSetDetailView(store: detailStore)
          } accessory: { detailStore in
            TimetableScheduleToast(isVisible: detailStore.isScheduleToastVisible)
          }
        }
      }
      .overlay {
        if store.selectedTab == .my {
          Color.clear
            .fcAlert(
              $store.scope(
                \.tabs.profile.destination?.alert,
                action: \.scopeAction.profileCoordinator.profile.destination.alert
              ),
              dismissesOnDimTap: true
            )
        }
      }
      .fcModal(
        item: authSheet,
        height: authSheet.wrappedValue == .onboarding ? .fraction(1) : .auto,
        showsGrabber: authSheet.wrappedValue != .onboarding
      ) { sheet in
        authSheetContent(sheet)
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
          \.tabs.festival,
          action: \.scopeAction.festival
        )
      )

    case .timetable:
      timetableView

    case .flag:
      FestivalFlagView(
        store: store.scope(
          \.tabs.flag,
          action: \.scopeAction.flag
        )
      )

    case .my:
      profileView
    }
  }

  var profileView: some View {
    ProfileCoordinatorView(store: store.scope(
      \.tabs.profile,
      action: \.scopeAction.profileCoordinator
    ))
  }

  var timetableView: some View {
    TimetableCoordinatorView(store: store.scope(
      \.tabs.timetable,
      action: \.scopeAction.timetableCoordinator
    ))
  }
}

#Preview {
  MainTabView(
    store: Store(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    }
  )
}
