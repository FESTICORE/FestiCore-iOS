//
//  SettingsHomeFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 11/12/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import Testing
@testable import Profile

@MainActor
struct SettingsHomeFeatureTests {
  @Test("로그아웃 상태의 설정 홈은 계정 그룹을 숨기고 계정 줄 입력을 무시한다")
  func guestHidesAccountGroup() async {
    #expect(!SettingsHomeFeature.State().showsAccount)
    #expect(SettingsHomeFeature.State(hasSession: true).showsAccount)

    let store = TestStore(initialState: SettingsHomeFeature.State()) { SettingsHomeFeature() }
    await store.send(.view(.accountTapped))
  }

  @Test("뒤로 가기는 마이 화면에 닫기를 요청한다")
  func backRequestsDismiss() async {
    let store = TestStore(initialState: SettingsHomeFeature.State()) { SettingsHomeFeature() }

    await store.send(.view(.backTapped))
    await store.receive(\.delegate.backRequested)
  }

  @Test func accountTapOpensAccountScreenAndForwardsAccountChanges() async {
    let store = TestStore(initialState: signedInState()) { SettingsHomeFeature() }

    await store.send(.view(.accountTapped)) {
      $0.destination = .account(.init(profile: nil))
    }
    await store.send(.view(.accountChanged(
      profile: nil,
      hasSession: true,
      isLoading: true,
      message: nil
    ))) {
      $0.isLoading = true
    }
    await store.receive(\.destination.presented.account.view.accountChanged) {
      $0.destination = .account(.init(
        profile: nil,
        isLoading: true
      ))
    }
  }

  @Test func losingSessionClosesAccountScreen() async {
    var state = signedInState()
    state.destination = .account(.init(profile: nil))
    let store = TestStore(initialState: state) { SettingsHomeFeature() }

    await store.send(.view(.accountChanged(
      profile: nil,
      hasSession: false,
      isLoading: false,
      message: nil
    ))) {
      $0.hasSession = false
      $0.destination = nil
    }
  }

  @Test func accountScreenRequestsAreForwardedToProfile() async {
    let user = AuthUser(
      id: "user-a",
      provider: "apple",
      email: nil,
      nickname: "새이름",
      nicknameConfirmed: true,
      termsAcceptedAt: "2026-10-01",
      termsVersion: "2026-10",
      pushOptIn: false,
      profileImageURL: nil
    )
    var state = signedInState()
    state.destination = .account(.init(profile: nil))
    let store = TestStore(initialState: state) { SettingsHomeFeature() }

    await store.send(.destination(.presented(.account(.delegate(.logoutRequested)))))
    await store.receive(\.delegate.logoutRequested)
    await store.send(.destination(.presented(.account(.delegate(.withdrawRequested)))))
    await store.receive(\.delegate.withdrawRequested)
    await store.send(.destination(.presented(.account(.delegate(.refreshRequested)))))
    await store.receive(\.delegate.profileRefreshRequested)
    await store.send(.destination(.presented(.account(.delegate(.nicknameUpdated(user))))))
    await store.receive(\.delegate.profileUpdated)
    await store.send(.destination(.presented(.account(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test func notificationsTapOpensNotificationSettings() async {
    let store = TestStore(initialState: SettingsHomeFeature.State()) { SettingsHomeFeature() }

    await store.send(.view(.notificationsTapped)) {
      $0.destination = .notifications(.init())
    }
    await store.send(.destination(.presented(.notifications(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test(arguments: [true, false])
  func closingNotificationSettingsStillSendsUnsavedChanges(viaBackButton: Bool) async {
    let sent = LockIsolated<[[NotificationSettingsFeature.Kind: Bool]]>([])
    var notifications = NotificationSettingsFeature.State()
    notifications.settings = FestivalNotificationSettings(
      flagStatus: false,
      crewStatus: false
    )
    notifications.isSaving = true
    notifications.savingChanges = [.flagStatus: false]
    notifications.pendingChanges = [.crewStatus: false]
    var state = SettingsHomeFeature.State()
    state.destination = .notifications(notifications)
    let store = TestStore(initialState: state) {
      SettingsHomeFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        updateSettings: { changes in
          sent.withValue { $0.append(changes) }
          return FestivalNotificationSettings(
            flagStatus: false,
            crewStatus: false
          )
        }
      )
    }

    if viaBackButton {
      await store.send(.destination(.presented(.notifications(.delegate(.backRequested))))) {
        $0.destination = nil
      }
    } else {
      // 뒤로 밀어 닫으면 내비게이션이 dismiss를 보낸다.
      await store.send(.destination(.dismiss)) { $0.destination = nil }
    }
    await store.finish()
    #expect(sent.value == [[.flagStatus: false, .crewStatus: false]])
  }

  @Test func missingLegalConfigurationShowsDismissibleError() async {
    let store = TestStore(initialState: SettingsHomeFeature.State()) {
      SettingsHomeFeature()
    }

    await store.send(.view(.termsTapped)) {
      $0.destination = .alert(.legalLinkUnavailable())
    }
    // 이미 떠 있는 팝업에 같은 동작이 다시 와도 새로 띄우지 않는다.
    await store.send(.view(.privacyTapped))
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
    }
  }

  @Test func lockScreenRowOpensScreenAndBackReturnsToSettings() async {
    let store = TestStore(initialState: SettingsHomeFeature.State()) { SettingsHomeFeature() }

    await store.send(.view(.lockScreenTapped)) {
      $0.destination = .lockScreen(.init())
    }
    await store.send(.destination(.presented(.lockScreen(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test func appearanceRowOpensScreenAndBackReturnsToSettings() async {
    let store = TestStore(initialState: SettingsHomeFeature.State()) { SettingsHomeFeature() }

    await store.send(.view(.appearanceTapped)) {
      $0.destination = .appearance(.init())
    }
    await store.send(.destination(.presented(.appearance(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test func noticeRowOpensListAndBackReturnsToSettings() async {
    let store = TestStore(initialState: SettingsHomeFeature.State()) { SettingsHomeFeature() }

    await store.send(.view(.noticeTapped)) {
      $0.destination = .noticeList(.init())
    }
    await store.send(.destination(.presented(.noticeList(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  private func signedInState() -> SettingsHomeFeature.State {
    return SettingsHomeFeature.State(hasSession: true)
  }
}
