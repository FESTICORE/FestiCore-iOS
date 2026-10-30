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

    /// 목록에서는 탭바를 숨기고, 선택한 축제의 라이브 보드에서는 표시한다.
    var shouldHideTabBar: Bool {
      switch selectedTab {
      case .live:
        return homeState.routes.count == 1
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
        if tab == .timetable {
          syncTimetable(state: &state)
        }
        return .none

      case let .tabReselected(tab):
        _ = tab
        return .none

      case .home:
        if state.selectedTab == .timetable {
          syncTimetable(state: &state)
        }
        return .none

      case .timetable:
        return .none
      }
    }
  }

  private func syncTimetable(state: inout State) {
    guard let screen = state.homeState.routes.last?.screen,
          case let .liveBoard(home) = screen,
          let pack = home.selectedPack else { return }
    let days = FestivalPackTimetableMapper.days(from: pack)
    guard state.timetableState.days != days else { return }
    let selectedID = state.timetableState.selectedDay?.id
    state.timetableState.days = days
    state.timetableState.selectedDayIndex = days.firstIndex { $0.id == selectedID } ?? 0
    state.timetableState.source = "저장된 축제 팩"
  }
}
