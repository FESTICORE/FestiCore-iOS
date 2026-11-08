//
//  AppDelegate+Push.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import UIKit
import UserNotifications

extension AppDelegate {
  /// 알림 탭과 앱 실행 중 알림 표시를 이 델리게이트가 받는다. 앱 시작 직후 지정해야 콜드 스타트 탭도 받는다.
  func configurePushHandling() {
    UNUserNotificationCenter.current().delegate = self
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
