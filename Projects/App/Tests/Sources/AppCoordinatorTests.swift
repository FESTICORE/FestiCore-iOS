//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Foundation
import Testing

import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import TCAFlow
@testable import FestiCore

@MainActor
struct AppCoordinatorTests {
  @Test func startsAtSplash() {
    #expect(AppCoordinator.State() == .splash(.init()))
  }

  @Test func splashCompletionShowsHome() async {
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalCatalogService = EmptyFestivalCatalogService()
    }
    await store.send(.scope(.splash(.delegate(.presentHome))))
    await store.receive(\.view.presentHome)
    await store.receive(\.inner.completeHomeTransition) {
      $0 = .home(.init())
    }
  }

  @Test func repeatedHomeTransitionKeepsExistingState() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) {
      AppCoordinator()
    } withDependencies: {
      $0.festivalCatalogService = EmptyFestivalCatalogService()
    }
    await store.send(.inner(.completeHomeTransition))
  }

  @Test func tappingTabSwitchesAndRemembersPreviousTab() async {
    let store = TestStore(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    }
    await store.send(.tabTapped(.timetable))
    await store.receive(\.selectTab) {
      $0.selectedTab = .timetable
      $0.previousTab = .live
    }
    await store.send(.tabTapped(.timetable))
    await store.receive(\.tabReselected)
  }

  @Test func homeCoordinatorStartsWithFestivalFeatureRoute() {
    let coordinator = FestivalCoordinator.State()
    #expect(coordinator.routes.count == 1)
    #expect(coordinator.routes.first?.screen.festivalList != nil)
  }

  @Test func bottomTabsAppearOnFestivalLiveBoard() {
    var state = MainTabCoordinator.State()
    #expect(state.shouldHideTabBar)

    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    #expect(!state.shouldHideTabBar)

    state.festivalState.routes.goBack()
    #expect(state.shouldHideTabBar)
  }

  @Test func swipingBackFromLiveBoardReturnsToFestivalList() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    let store = TestStore(initialState: state) {
      FestivalCoordinator()
    }

    await store.send(.router(.routeAction(id: 1, action: .liveBoard(.view(.backToFestivalList))))) {
      $0.routes.goBack()
    }
  }

  @Test func timetableUsesSelectedFestivalPackTimes() throws {
    let payload = #"{"id":"festival","stages":[{"id":"main","name":"메인 무대"}],"sets":[{"id":"set-1","artist":"가수","stageId":"main","startsAt":"2026-10-30T12:00:00+09:00","endsAt":"2026-10-30T13:00:00+09:00"}]}"#
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(payload.utf8))

    let days = FestivalPackTimetableMapper.days(from: pack)

    #expect(days.count == 1)
    #expect(days.first?.id == "2026-10-30")
    #expect(days.first?.stages.first?.name == "메인 무대")
    #expect(days.first?.sets.first?.start == 720)
    #expect(days.first?.sets.first?.end == 780)
  }
}

private struct EmptyFestivalCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { [] }
  func refresh() async throws -> [FestivalCatalogItem] { [] }
}
