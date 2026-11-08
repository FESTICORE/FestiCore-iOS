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
  /// 어느 탭에서든 fcModal 시트가 뜨면 탭바를 먼저 숨긴 채 시트를 올린다.
  @State private var isModalPresented = false

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
          .opacity(isTabBarHidden ? 0 : 1)
          .allowsHitTesting(!isTabBarHidden)
          // 시트 이동 애니메이션과 별개로 탭바는 즉시 사라지고 나타난다.
          .animation(
            nil,
            value: isTabBarHidden
          )
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
        }
      }
      .overlay {
        if store.selectedTab == .my {
          Color.clear
            .fcAlert(
              $store.scope(
                state: \.profileState.destination?.alert,
                action: \.profileCoordinator.profile.destination.alert
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
      .fullScreenCover(item: $store.scope(
        state: \.bearerEntry,
        action: \.bearerEntry
      )) { bearerStore in
        BearerEntryCoordinatorView(store: bearerStore)
      }
      .onPreferenceChange(FCModalPresentedKey.self) { isModalPresented = $0 }
  }
}

private extension MainTabView {
  var isTabBarHidden: Bool {
    return store.shouldHideTabBar || isModalPresented
  }

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
      FlagCoordinatorView(store: store.scope(
        state: \.flagCoordinatorState,
        action: \.flagCoordinator
      ))

    case .my:
      profileView
    }
  }

  var profileView: some View {
    ProfileCoordinatorView(store: store.scope(
      state: \.profileState,
      action: \.profileCoordinator
    ))
  }

  var timetableView: some View {
    TimetableCoordinatorView(store: store.scope(
      state: \.timetableCoordinatorState,
      action: \.timetableCoordinator
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
