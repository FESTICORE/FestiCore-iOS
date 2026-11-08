//
//  AppearanceSettingsFeatureTests.swift
//  ProfileTests
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
@testable import Profile

@MainActor
struct AppearanceSettingsFeatureTests {
  /// 테스트마다 빈 저장소를 써서 다른 테스트가 고른 값과 섞이지 않게 한다.
  private func makeStore() -> TestStoreOf<AppearanceSettingsFeature> {
    return TestStore(initialState: AppearanceSettingsFeature.State()) {
      AppearanceSettingsFeature()
    } withDependencies: {
      $0.defaultAppStorage = UserDefaults(suiteName: "AppearanceSettingsFeatureTests.\(UUID().uuidString)")!
    }
  }

  @Test("기본은 지금까지처럼 다크이고, 고르면 바로 저장한다")
  func selectsAndPersistsMode() async {
    let store = makeStore()
    #expect(store.state.mode == .dark)

    await store.send(.view(.modeTapped(.system))) {
      $0.$mode.withLock { $0 = .system }
    }
    await store.send(.view(.modeTapped(.light))) {
      $0.$mode.withLock { $0 = .light }
    }
  }

  @Test("뒤로 가면 마이로 돌아간다")
  func backReturns() async {
    let store = makeStore()

    await store.send(.view(.backTapped))
    await store.receive(.delegate(.backRequested))
  }

  @Test("시스템 설정과 같게는 기기 설정을 따르고 마이에는 짧은 이름으로 보인다")
  func modePresentation() {
    #expect(AppearanceMode.system.colorScheme == nil)
    #expect(AppearanceMode.light.colorScheme == .light)
    #expect(AppearanceMode.dark.colorScheme == .dark)
    #expect(AppearanceMode.allCases.map(\.title) == [
      "시스템 설정과 같게",
      "라이트",
      "다크"
    ])
    #expect(AppearanceMode.system.summary == "시스템 설정")
  }
}
