//
//  LockScreenSettingsFeatureTests.swift
//  Profile
//

import ComposableArchitecture
import Foundation
import Testing
import UIKit
@testable import Profile

@MainActor
struct LockScreenSettingsFeatureTests {
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
}
