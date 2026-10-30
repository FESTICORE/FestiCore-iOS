//
//  AppDelegate+DeviceRegistration.swift
//  FestiCore
//
//  Created by FestiCore on 10/29/26.
//

import UIKit
import UserNotifications

import CoreAssembly
import FestiCoreLiveActivity
import ServiceAssembly

extension AppDelegate {
  func configureDeviceRegistration() {
    liveActivityStartToken = FestiCoreFestivalLiveActivity.pushToStartToken
    registerDeviceWithStoredAPNsToken()
    registerForRemoteNotificationsIfNeeded()
    observeLiveActivityStartToken()
  }

  func requestNotificationPermission() async -> NotificationPermissionResult {
    if let notificationAuthorizationTask {
      return await notificationAuthorizationTask.value
    }
    let task = Task { @MainActor in
      await resolveNotificationPermission()
    }
    notificationAuthorizationTask = task
    let result = await task.value
    notificationAuthorizationTask = nil
    return result
  }

  private func resolveNotificationPermission() async -> NotificationPermissionResult {
    let status = await notificationAuthorizationClient.authorizationStatus()
    let result: NotificationPermissionResult
    switch status {
    case .notDetermined:
      do {
        result = try await notificationAuthorizationClient.requestAuthorization() ? .authorized : .denied
      } catch {
        FestiCoreLogger.error("알림 권한 요청 실패: \(error.localizedDescription)", category: .app)
        result = .unavailable
      }
    case .authorized, .provisional, .ephemeral:
      result = .authorized
    case .denied:
      result = .denied
    @unknown default:
      result = .unavailable
    }

    registerForRemoteNotificationsIfNeeded()
    return result
  }

  private func registerForRemoteNotificationsIfNeeded() {
    guard !hasRequestedAPNsRegistration else { return }
    hasRequestedAPNsRegistration = true
    notificationAuthorizationClient.registerForRemoteNotifications()
  }

  private func observeLiveActivityStartToken() {
    liveActivityStartTokenTask?.cancel()
    liveActivityStartTokenTask = Task { @MainActor [weak self] in
      for await token in FestiCoreFestivalLiveActivity.pushToStartTokenUpdates() {
        guard let self, !Task.isCancelled else { return }
        guard liveActivityStartToken != token else { continue }
        liveActivityStartToken = token
        registerDeviceWithStoredAPNsToken()
      }
    }
  }

  private func registerDeviceWithStoredAPNsToken() {
    let apnsToken: String?
    do {
      apnsToken = try secureStorage.load(.apnsToken)
    } catch {
      FestiCoreLogger.error("저장된 APNs 토큰 조회 실패: \(error.localizedDescription)", category: .app)
      apnsToken = nil
    }
    registerDevice(apnsToken: apnsToken)
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    do {
      try secureStorage.save(apnsToken, for: .apnsToken)
    } catch {
      FestiCoreLogger.error("APNs 토큰 저장 실패: \(error.localizedDescription)", category: .app)
    }
    registerDevice(apnsToken: apnsToken)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    hasRequestedAPNsRegistration = false
    FestiCoreLogger.error("APNs 토큰 등록 실패: \(error.localizedDescription)", category: .app)
  }

  private func registerDevice(apnsToken: String?) {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    let apnsEnvironment: DeviceRegistrationMetadata.APNsEnvironment
    switch infoDictionary["FestiCoreAPNsEnvironment"] as? String {
    case "development": apnsEnvironment = .sandbox
    case "production": apnsEnvironment = .production
    default:
      FestiCoreLogger.error("기기 등록 건너뜀: FestiCoreAPNsEnvironment 설정이 유효하지 않음", category: .app)
      return
    }
    guard let appVersion = infoDictionary["CFBundleShortVersionString"] as? String, !appVersion.isEmpty else {
      FestiCoreLogger.error("기기 등록 건너뜀: CFBundleShortVersionString 설정이 유효하지 않음", category: .app)
      return
    }

    let metadata = DeviceRegistrationMetadata(
      apnsEnvironment: apnsEnvironment,
      apnsToken: apnsToken,
      liveActivityPushToStartToken: liveActivityStartToken,
      appVersion: appVersion,
      osVersion: UIDevice.current.systemVersion,
      locale: Locale.current.identifier(.bcp47),
      timezone: TimeZone.current.identifier
    )

    let previousRegistration = registrationTask
    registrationTask = Task {
      await previousRegistration?.value
      guard lastRegisteredDeviceMetadata != metadata else { return }
      do {
        _ = try await deviceRegistrationService.register(metadata)
        lastRegisteredDeviceMetadata = metadata
      } catch {
        FestiCoreLogger.error("기기 등록 실패: \(error.localizedDescription)", category: .app)
      }
    }
  }
}

enum NotificationPermissionResult: Equatable, Sendable {
  case authorized
  case denied
  case unavailable
}

@MainActor
struct NotificationAuthorizationClient {
  var authorizationStatus: () async -> UNAuthorizationStatus
  var requestAuthorization: () async throws -> Bool
  var registerForRemoteNotifications: () -> Void

  static let live = Self(
    authorizationStatus: {
      await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    },
    requestAuthorization: {
      try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    },
    registerForRemoteNotifications: {
      UIApplication.shared.registerForRemoteNotifications()
    }
  )
}
