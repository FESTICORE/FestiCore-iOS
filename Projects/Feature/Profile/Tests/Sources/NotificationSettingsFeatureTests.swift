//
//  NotificationSettingsFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Profile

@MainActor
struct NotificationSettingsFeatureTests {
  @Test func appearLoadsPermissionAndSettings() async {
    let settings = FestivalNotificationSettings(crewStatus: false)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .allowed },
        settings: { settings }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.permission = .allowed
      $0.settings = settings
      $0.load = .loaded
    }
  }

  @Test func toggleSavesAndRevertsOnFailure() async {
    let attempts = LockIsolated(0)
    var state = NotificationSettingsFeature.State()
    state.permission = .allowed
    state.settings = FestivalNotificationSettings()
    state.load = .loaded
    let store = TestStore(initialState: state) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        updateSettings: { new in
          attempts.withValue { $0 += 1 }
          if attempts.value == 2 { throw URLError(.notConnectedToInternet) }
          return new
        }
      )
    }

    await store.send(.view(.toggled(.packUpdates, false))) { $0.settings?.packUpdates = false }
    await store.receive(\.async.save)
    await store.receive(\.inner.saved)
    await store.send(.view(.toggled(.crewGather, false))) { $0.settings?.crewGather = false }
    await store.receive(\.async.save)
    await store.receive(\.inner.saveFailed) {
      $0.settings?.crewGather = true
      $0.message = "알림 설정을 저장하지 못했어요. 다시 시도해 주세요."
    }
  }

  @Test func deviceNotificationOffBlocksToggles() async {
    var state = NotificationSettingsFeature.State()
    state.permission = .denied
    state.settings = FestivalNotificationSettings()
    state.load = .loaded
    let store = TestStore(initialState: state) { NotificationSettingsFeature() }

    #expect(store.state.isDeviceNotificationOff)
    await store.send(.view(.toggled(.flagStatus, false)))
  }

  @Test func settingsFailureShowsRetry() async {
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .notDetermined },
        settings: { throw FestivalNotificationSettingsError.deviceNotRegistered }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.permission = .notDetermined
      $0.load = .failed
    }
  }
}
