//
//  AppCoordinatorTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import Foundation
import Testing

import ComposableArchitecture
import FestivalDomainInterface
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

  @Test func homeCoordinatorStartsWithHomeFeatureRoute() {
    let coordinator = HomeCoordinator.State()
    #expect(coordinator.routes.count == 1)
    #expect(coordinator.routes.first?.screen.home != nil)
  }
}

private struct EmptyFestivalCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { [] }
  func refresh() async throws -> [FestivalCatalogItem] { [] }
}
