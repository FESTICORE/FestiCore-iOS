//
//  LockScreenSettingsFeatureTests.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreStorageInterface
import FestivalDomainInterface
import Foundation
import Testing
import UIKit
@testable import Profile

@MainActor
struct LockScreenSettingsFeatureTests {
  @Test func autoStartToggleSavesSharedValue() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    }

    #expect(store.state.isAutoStartOn)
    await store.send(.view(.autoStartToggled(false))) {
      $0.$isAutoStartOn.withLock { $0 = false }
    }
    @Shared(.liveActivityAutoStart) var isAutoStartOn
    #expect(!isAutoStartOn)
  }

  @Test func appearLoadsActiveActivities() async {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let activity = FestivalLiveActivityRecord(
      id: "activity-1", festivalID: "festival-1", phase: .ongoing,
      startDate: now, endDate: nil
    )
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(activities: { [activity] })
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.activities = [activity]
    }
  }

  @Test func emptyActivitiesFinishLoading() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(activities: { [] })
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.isLoading = false
      $0.hasLoaded = true
    }
    #expect(store.state.activityCount == 0)
  }

  @Test func reappearingRefreshesActivityCount() async {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let activity = FestivalLiveActivityRecord(
      id: "activity-1", festivalID: "festival-1", phase: .upcoming,
      startDate: now, endDate: nil
    )
    let calls = LockIsolated(0)
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(activities: {
        calls.withValue {
          $0 += 1
          return $0 == 1 ? [activity] : []
        }
      })
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.activities = [activity]
    }
    await store.send(.view(.onAppear))
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.isLoading = false
      $0.activities = []
    }
    #expect(calls.value == 2)
  }

  @Test func settingsButtonOpensAppSettingsAndBackRequestsDismissal() async {
    let openedURL = LockIsolated<URL?>(nil)
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.openURL = .init { url in
        openedURL.setValue(url)
        return true
      }
    }

    await store.send(.view(.openSystemSettingsTapped))
    await store.finish()
    #expect(openedURL.value?.absoluteString == UIApplication.openSettingsURLString)
    await store.send(.view(.backTapped))
    await store.receive(\.delegate.backRequested)
  }

  @Test func stopAllEndsEachActivityAndRefreshesList() async {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let activities = ["one", "two"].map {
      FestivalLiveActivityRecord(
        id: $0,
        festivalID: $0,
        phase: .ongoing,
        startDate: now,
        endDate: nil
      )
    }
    let ended = LockIsolated<[String]>([])
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(
        activities: { ended.value.isEmpty ? activities : [] },
        end: { id in ended.withValue { $0.append(id) } }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.activities = activities
    }
    await store.send(.view(.stopAllTapped)) { $0.isStopping = true }
    await store.receive(\.async.stopActivities)
    await store.receive(\.inner.activitiesStopped)
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.activities = []
      $0.isStopping = false
    }
    #expect(ended.value == ["one", "two"])
    #expect(store.state.activityCount == 0)
  }
}
