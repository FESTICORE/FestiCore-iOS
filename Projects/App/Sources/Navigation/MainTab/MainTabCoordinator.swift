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
  @Dependency(\.festivalBookedStore) private var bookedStore

  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab
    var previousTab: Tab = .live
    var festivalState: FestivalCoordinator.State
    var timetableState: TimetableFeature.State
    var loginState = LoginFeature.State()
    var authFlow = AppCoordinator.AuthFlow()

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
    case login(LoginFeature.Action)
    case completePendingBookmark(id: String, userID: String, shouldBeBooked: Bool)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.festivalState, action: \.festival) {
      FestivalCoordinator()
    }
    Scope(state: \.timetableState, action: \.timetable) {
      TimetableFeature()
    }
    Scope(state: \.loginState, action: \.login) {
      LoginFeature()
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

      case .festival:
        if state.selectedTab == .timetable {
          syncTimetable(state: &state)
        }
        return .none

      case .timetable:
        return .none

      case .login:
        return .none

      case let .completePendingBookmark(id, userID, shouldBeBooked):
        guard state.authFlow.verifiedUserID == userID,
              (state.authFlow.profile?.isEligible == true
                || (state.authFlow.profile == nil && bookedStore.offlineEligible(userID))) else { return .none }
        bookedStore.setBookmark(id, booked: shouldBeBooked, for: userID)
        return .send(.festival(.reloadBookmarks(userID: userID)))
      }
    }
  }

  private func syncTimetable(state: inout State) {
    guard let screen = state.festivalState.routes.last?.screen,
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
