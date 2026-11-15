import ComposableArchitecture
import Foundation
import Testing
import UIKit

import FestiCoreSharedUI
@testable import FestiCore

@MainActor
struct NotificationSettingsAlertTests {
  @Test("거부 안내는 세션에서 한 번만 띄운다")
  func deniedShowsAlertOnce() async {
    let store = TestStore(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    }

    await store.send(.notificationPermissionResolved(.denied)) {
      $0.notificationSettingsAlert = .notificationSettings()
      $0.hasShownNotificationSettingsAlert = true
    }
    await store.send(.notificationSettingsAlert(.presented(.cancelTapped))) {
      $0.notificationSettingsAlert = nil
    }
    await store.send(.notificationPermissionResolved(.denied))
  }

  @Test("허용 또는 권한 조회 실패는 안내 기록을 소모하지 않는다")
  func otherResultsKeepAlertAvailable() async {
    let store = TestStore(initialState: MainTabCoordinator.State()) {
      MainTabCoordinator()
    }

    await store.send(.notificationPermissionResolved(.authorized))
    await store.send(.notificationPermissionResolved(.unavailable))
    await store.send(.notificationPermissionResolved(.denied)) {
      $0.notificationSettingsAlert = .notificationSettings()
      $0.hasShownNotificationSettingsAlert = true
    }
  }

  @Test("설정 열기를 누르면 안내를 닫고 설정 URL을 연다")
  func confirmOpensSettings() async {
    let openedURL = LockIsolated<URL?>(nil)
    var state = MainTabCoordinator.State()
    state.notificationSettingsAlert = .notificationSettings()
    state.hasShownNotificationSettingsAlert = true
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    } withDependencies: {
      $0.openURL = .init { url in
        openedURL.setValue(url)
        return true
      }
    }

    await store.send(.notificationSettingsAlert(.presented(.confirmTapped))) {
      $0.notificationSettingsAlert = nil
    }
    await store.finish()
    #expect(openedURL.value?.absoluteString == UIApplication.openSettingsURLString)
  }

  @Test("안내 문구는 설정 열기와 나중에 버튼을 보인다")
  func alertCopy() {
    let alert = FCAlertState<FCAlertAction>.notificationSettings()
    #expect(alert.title == "알림이 꺼져 있어요")
    #expect(alert.message == "알림을 받으려면 설정에서 알림을 허용해 주세요. 알림 없이도 앱을 사용할 수 있어요.")
    #expect(alert.confirmTitle == "설정 열기")
    #expect(alert.cancelTitle == "나중에")
  }

  @Test("홈에서 받은 권한 결과를 메인 탭에 전달한다")
  func appCoordinatorForwardsResultOnHome() async {
    let store = TestStore(initialState: AppCoordinator.State.home(.init())) {
      AppCoordinator()
    }

    await store.send(.view(.notificationPermissionResolved(.denied)))
    await store.receive(\.scope.home.notificationPermissionResolved) {
      var home = MainTabCoordinator.State()
      home.notificationSettingsAlert = .notificationSettings()
      home.hasShownNotificationSettingsAlert = true
      $0 = .home(home)
    }
  }

  @Test("홈이 아니면 권한 결과를 무시한다")
  func appCoordinatorIgnoresResultBeforeHome() async {
    let store = TestStore(initialState: AppCoordinator.State()) {
      AppCoordinator()
    }

    await store.send(.view(.notificationPermissionResolved(.denied)))
  }
}
