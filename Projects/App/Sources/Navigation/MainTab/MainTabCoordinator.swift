//
//  MainTabCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestiCoreDesignKit
import Foundation

@Reducer
struct MainTabCoordinator {
  typealias Tab = FCTabBar.Tab

  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab
    var previousTab: Tab = .live
    var homeState: HomeCoordinator.State
    var timetableState: TimetableFeature.State

    /// 하위 화면으로 들어가면 탭바를 숨긴다.
    var shouldHideTabBar: Bool {
      switch selectedTab {
      case .live:
        return homeState.routes.count > 1
      case .timetable, .flag, .my:
        return false
      }
    }

    init(selectedTab: Tab = .live) {
      self.selectedTab = selectedTab
      homeState = .init()
      timetableState = .init(
        days: [],
        source: ""
      )
    }
  }

  @CasePathable
  enum Action {
    case tabTapped(Tab)
    case selectTab(Tab)
    case tabReselected(Tab)
    case home(HomeCoordinator.Action)
    case timetable(TimetableFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.homeState, action: \.home) {
      HomeCoordinator()
    }
    Scope(state: \.timetableState, action: \.timetable) {
      TimetableFeature()
    }

    Reduce { state, action in
      switch action {
      case let .tabTapped(tab):
        return .send(tab == state.selectedTab ? .tabReselected(tab) : .selectTab(tab))

      case let .selectTab(tab):
        if tab != state.selectedTab {
          state.previousTab = state.selectedTab
        }
        state.selectedTab = tab
        return .none

      case let .tabReselected(tab):
        if tab == .live {
          state.homeState.routes.goBackToRoot()
        }
        return .none

      case .home, .timetable:
        return .none
      }
    }
  }
}
