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
    var festivalState: FestivalCoordinator.State
    var timetableState: TimetableFeature.State

    /// 목록에서는 탭바를 숨기고, 선택한 축제의 라이브 보드에서는 표시한다.
    var shouldHideTabBar: Bool {
      switch selectedTab {
      case .live:
        return festivalState.routes.count == 1
      case .timetable, .flag, .my:
        return false
      }
    }

    init(selectedTab: Tab = .live) {
      self.selectedTab = selectedTab
      festivalState = .init()
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
    case festival(FestivalCoordinator.Action)
    case timetable(TimetableFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.festivalState, action: \.festival) {
      FestivalCoordinator()
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
        guard tab == .timetable else { return .none }
        return syncTimetable(state: &state, appearing: true)

      case let .tabReselected(tab):
        _ = tab
        return .none

      case .festival:
        guard state.selectedTab == .timetable else { return .none }
        return syncTimetable(state: &state, appearing: false)

      case .timetable:
        return .none
      }
    }
  }

  /// 라이브 보드에서 고른 축제의 팩을 타임테이블에 옮긴다.
  /// 고른 축제가 없으면 이전 축제의 시간표가 남지 않게 비운다.
  private func syncTimetable(
    state: inout State,
    appearing: Bool
  ) -> Effect<Action> {
    var selected: (festivalID: String?, pack: FestivalPackDocument)?
    if let screen = state.festivalState.routes.last?.screen,
       case let .liveBoard(home) = screen,
       let pack = home.selectedPack {
      selected = (home.selectedFestivalID, pack)
    }
    let days = selected.map { FestivalPackTimetableMapper.days(from: $0.pack) } ?? []
    let daysChanged = state.timetableState.days != days
    if daysChanged {
      let selectedID = state.timetableState.selectedDay?.id
      state.timetableState.days = days
      state.timetableState.selectedDayIndex = days.firstIndex { $0.id == selectedID } ?? 0
      state.timetableState.source = selected == nil ? "" : "저장된 축제 팩"
    }

    let festivalID = selected?.festivalID
    if festivalID != state.timetableState.festivalID {
      return .send(.timetable(.festivalChanged(festivalID)))
    }
    var effects: [Effect<Action>] = []
    if daysChanged {
      effects.append(.send(.timetable(.packUpdated)))
    }
    if appearing {
      effects.append(.send(.timetable(.timetableAppeared)))
    }
    return .concatenate(effects)
  }
}
