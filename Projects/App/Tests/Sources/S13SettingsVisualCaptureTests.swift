import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Profile

/// Figma S13 A~E 설정(알림·기기 알림 꺼짐·잠금화면·계정·로그아웃 확인)을 고정 상태로 렌더한다(다크 393). 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCaptureSettingsStates() async throws {
    for permission in [
      FestivalNotificationPermission.allowed,
      FestivalNotificationPermission.denied,
    ] {
      var state = NotificationSettingsFeature.State()
      state.load = .loaded
      state.permission = permission
      state.settings = FestivalNotificationSettings()
      let store = Store(initialState: state) {
        EmptyReducer<NotificationSettingsFeature.State, NotificationSettingsFeature.Action>()
      }
      try await capture(
        NotificationSettingsView(store: store),
        name: permission == .allowed ? "S13-A-notifications" : "S13-B-device-off",
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }

    var lockScreen = LockScreenSettingsFeature.State()
    lockScreen.isLoading = false
    lockScreen.hasLoaded = true
    try await capture(
      LockScreenSettingsView(store: Store(initialState: lockScreen) {
        EmptyReducer<LockScreenSettingsFeature.State, LockScreenSettingsFeature.Action>()
      }),
      name: "S13-C-lockscreen",
      size: CGSize(
        width: 393,
        height: 852
      )
    )

    for confirmsLogout in [
      false,
      true,
    ] {
      var account = AccountSettingsFeature.State(profile: settingsProfile)
      if confirmsLogout {
        account.confirmation = .logout
        account.destination = .alert(.logout())
      }
      try await capture(
        AccountSettingsView(store: Store(initialState: account) {
          EmptyReducer<AccountSettingsFeature.State, AccountSettingsFeature.Action>()
        }),
        name: confirmsLogout ? "S13-E-logout" : "S13-D-account",
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }
}

extension FestivalS01VisualCaptureTests {
  var settingsProfile: AuthProfile {
    return AuthProfile(
      user: AuthUser(
        id: "user-minji",
        provider: "apple",
        email: "minji@privaterelay.appleid.com",
        nickname: "로이",
        nicknameConfirmed: true,
        termsAcceptedAt: nil,
        termsVersion: "2026-10",
        pushOptIn: true,
        profileImageURL: nil
      ),
      currentTermsVersion: "2026-10"
    )
  }
}
