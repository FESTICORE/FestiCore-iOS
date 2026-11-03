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
      $0.lastConfirmed = settings
      $0.load = .loaded
    }
  }

  @Test func failedSaveReloadsServerValues() async {
    let server = LockIsolated(FestivalNotificationSettings())
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: loadedState()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .allowed },
        settings: { server.value },
        updateSettings: { changes in
          attempts.withValue { $0 += 1 }
          if attempts.value == 2 { throw URLError(.notConnectedToInternet) }
          server.withValue { for (kind, isOn) in changes { $0[kind] = isOn } }
          return server.value
        }
      )
    }

    await store.send(.view(.toggled(.packUpdates, false))) {
      $0.settings?.packUpdates = false
      $0.savingChanges = [.packUpdates: false]
      $0.isSaving = true
    }
    await store.receive(\.async.save, [.packUpdates: false])
    await store.receive(\.inner.saved) {
      $0.isSaving = false
      $0.savingChanges = [:]
      $0.lastConfirmed = FestivalNotificationSettings(packUpdates: false)
    }
    await store.send(.view(.toggled(.crewGather, false))) {
      $0.settings?.crewGather = false
      $0.savingChanges = [.crewGather: false]
      $0.isSaving = true
    }
    await store.receive(\.async.save, [.crewGather: false])
    await store.receive(\.inner.saveFailed) {
      $0.isSaving = false
      $0.savingChanges = [:]
      $0.settings?.crewGather = true
      $0.message = "알림 설정을 저장하지 못했어요. 다시 시도해 주세요."
    }
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded)
  }

  @Test func failedSaveAndReloadRestoreLastConfirmedSettings() async {
    let store = TestStore(initialState: loadedState()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .allowed },
        settings: { throw URLError(.notConnectedToInternet) },
        updateSettings: { _ in throw URLError(.notConnectedToInternet) }
      )
    }

    await store.send(.view(.toggled(.homecoming, false))) {
      $0.settings?.homecoming = false
      $0.savingChanges = [.homecoming: false]
      $0.isSaving = true
    }
    await store.receive(\.async.save)
    await store.receive(\.inner.saveFailed) {
      $0.isSaving = false
      $0.savingChanges = [:]
      $0.settings?.homecoming = true
      $0.message = "알림 설정을 저장하지 못했어요. 다시 시도해 주세요."
    }
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded)
    #expect(store.state.settings == FestivalNotificationSettings())
  }

  @Test func togglesWhileSavingAreSentAfterTheCurrentSave() async {
    let (gate, release) = AsyncStream.makeStream(of: Void.self)
    let sent = LockIsolated<[[NotificationSettingsFeature.Kind: Bool]]>([])
    let server = LockIsolated(FestivalNotificationSettings())
    let store = TestStore(initialState: loadedState()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        updateSettings: { changes in
          sent.withValue { $0.append(changes) }
          if sent.value.count == 1 { for await _ in gate { break } }
          server.withValue { for (kind, isOn) in changes { $0[kind] = isOn } }
          return server.value
        }
      )
    }

    await store.send(.view(.toggled(.flagStatus, false))) {
      $0.settings?.flagStatus = false
      $0.savingChanges = [.flagStatus: false]
      $0.isSaving = true
    }
    await store.receive(\.async.save, [.flagStatus: false])
    await store.send(.view(.toggled(.crewStatus, false))) {
      $0.settings?.crewStatus = false
      $0.pendingChanges = [.crewStatus: false]
    }
    await store.send(.view(.toggled(.homecoming, false))) {
      $0.settings?.homecoming = false
      $0.pendingChanges = [.crewStatus: false, .homecoming: false]
    }
    #expect(store.state.unsavedChanges == [.flagStatus: false, .crewStatus: false, .homecoming: false])
    release.yield()
    await store.receive(\.inner.saved) {
      $0.pendingChanges = [:]
      $0.savingChanges = [.crewStatus: false, .homecoming: false]
      $0.lastConfirmed = FestivalNotificationSettings(flagStatus: false)
    }
    await store.receive(\.async.save, [.crewStatus: false, .homecoming: false])
    await store.receive(\.inner.saved) {
      $0.isSaving = false
      $0.savingChanges = [:]
      $0.lastConfirmed = FestivalNotificationSettings(flagStatus: false, crewStatus: false, homecoming: false)
    }
    #expect(sent.value == [[.flagStatus: false], [.crewStatus: false, .homecoming: false]])
  }

  @Test func loadStartedBeforeSaveIsCancelledSoItCannotRevertToggles() async {
    let (gate, release) = AsyncStream.makeStream(of: Void.self)
    let store = TestStore(initialState: loadedState()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .allowed },
        settings: {
          // 저장보다 늦게 끝나는 조회
          for await _ in gate { break }
          return FestivalNotificationSettings()
        },
        updateSettings: { _ in FestivalNotificationSettings(packUpdates: false) }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.send(.view(.toggled(.packUpdates, false))) {
      $0.settings?.packUpdates = false
      $0.savingChanges = [.packUpdates: false]
      $0.isSaving = true
    }
    await store.receive(\.async.save)
    await store.receive(\.inner.saved) {
      $0.isSaving = false
      $0.savingChanges = [:]
      $0.lastConfirmed = FestivalNotificationSettings(packUpdates: false)
    }
    release.yield()
    #expect(store.state.settings?.packUpdates == false)
  }

  @Test func deviceNotificationOffBlocksToggles() async {
    var state = loadedState()
    state.permission = .denied
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

  private func loadedState() -> NotificationSettingsFeature.State {
    var state = NotificationSettingsFeature.State()
    state.permission = .allowed
    state.settings = FestivalNotificationSettings()
    state.lastConfirmed = FestivalNotificationSettings()
    state.load = .loaded
    return state
  }
}
