//
//  AppDelegate+Push.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import UIKit
import UserNotifications

import CoreAssembly

extension AppDelegate {
  /// 알림 탭과 앱 실행 중 알림 표시를 이 델리게이트가 받는다. 앱 시작 직후 지정해야 콜드 스타트 탭도 받는다.
  /// 지정한 뒤 곧바로 알림 권한을 묻는다. 허용·거부와 상관없이 APNs 등록을 시작하고, 토큰을 받으면 기기를 등록한다.
  func configurePushNotifications() {
    UNUserNotificationCenter.current().delegate = self
    // 앱 호스팅 테스트에서는 실제 권한 팝업을 띄우지 않는다.
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
    Task { _ = await requestNotificationPermission() }
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let apnsToken = deviceToken.map { byte in
      return String(
        format: "%02x",
        byte
      )
    }.joined()
    do {
      try secureStorage.save(
        apnsToken,
        for: .apnsToken
      )
    } catch {
      FestiCoreLogger.error(
        "APNs 토큰 저장 실패: \(error.localizedDescription)",
        category: .app
      )
    }
    registerDevice(apnsToken: apnsToken)
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    notificationAuthorization.hasRequestedAPNsRegistration = false
    FestiCoreLogger.error(
      "APNs 토큰 등록 실패: \(error.localizedDescription)",
      category: .app
    )
  }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
  /// 앱을 보고 있을 때도 배너·소리·목록으로 보인다.
  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent _: UNNotification
  ) async -> UNNotificationPresentationOptions {
    return [.banner, .list, .sound]
  }

  /// 알림 탭: payload를 딥링크로 바꿔 홈이 열 화면을 정하게 한다.
  func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    AppDeeplinkBridge.handlePushPayload(response.notification.request.content.userInfo)
  }
}
