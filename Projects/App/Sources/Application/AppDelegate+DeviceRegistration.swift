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
  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let request = RemoteContentRefreshRequest(completion: completionHandler)
    guard let remoteContentHandler else {
      // 씬 없이 백그라운드로 깨어나면 갱신할 화면 상태가 없다. 앱을 열 때 새로 받으므로 바로 마친다.
      request.finish(.noData)
      return
    }
    remoteContentHandler(request)
  }

  func configureDeviceRegistration() {
    deviceRegistration.liveActivityStartToken = FestiCoreFestivalLiveActivity.pushToStartToken
    registerDeviceWithStoredAPNsToken()
    registerForRemoteNotificationsIfNeeded()
    observeLiveActivityStartToken()
    let deviceRegistrationService = deviceRegistrationService
    deviceRegistration.liveActivityTokenSync = LiveActivityTokenSync(
      authorization: { [weak self] in
        await self?.deviceRegistration.task?.value
        if let authorization = try await deviceRegistrationService.authorization() {
          return authorization
        }
        self?.registerDeviceWithStoredAPNsToken()
        await self?.deviceRegistration.task?.value
        return try await deviceRegistrationService.authorization()
      },
      registrationService: liveActivityRegistrationService
    )
    deviceRegistration.liveActivityTokenSync?.start()
  }

  func requestNotificationPermission() async -> NotificationPermissionResult {
    if let task = notificationAuthorization.task {
      return await task.value
    }
    let task = Task { @MainActor in
      return await resolveNotificationPermission()
    }
    notificationAuthorization.task = task
    let result = await task.value
    notificationAuthorization.task = nil
    return result
  }

  private func resolveNotificationPermission() async -> NotificationPermissionResult {
    let status = await notificationAuthorization.client.authorizationStatus()
    let result: NotificationPermissionResult
    switch status {
    case .notDetermined:
      do {
        result = try await notificationAuthorization.client.requestAuthorization() ? .authorized : .denied
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
    guard !notificationAuthorization.hasRequestedAPNsRegistration else { return }
    notificationAuthorization.hasRequestedAPNsRegistration = true
    notificationAuthorization.client.registerForRemoteNotifications()
  }

  private func observeLiveActivityStartToken() {
    deviceRegistration.liveActivityStartTokenTask?.cancel()
    deviceRegistration.liveActivityStartTokenTask = Task { @MainActor [weak self] in
      for await token in FestiCoreFestivalLiveActivity.pushToStartTokenUpdates() {
        guard let self, !Task.isCancelled else { return }
        guard deviceRegistration.liveActivityStartToken != token else { continue }
        deviceRegistration.liveActivityStartToken = token
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

  func registerDevice(apnsToken: String?) {
    guard let metadata = PushRegistrationService.metadata(
      infoDictionary: Bundle.main.infoDictionary ?? [:],
      apnsToken: apnsToken,
      liveActivityStartToken: deviceRegistration.liveActivityStartToken,
      osVersion: UIDevice.current.systemVersion,
      locale: Locale.current.identifier(.bcp47),
      timezone: TimeZone.current.identifier
    ) else {
      FestiCoreLogger.error(
        "기기 등록 건너뜀: FestiCoreAPNsEnvironment 또는 CFBundleShortVersionString 설정이 유효하지 않음",
        category: .app
      )
      return
    }

    let previousRegistration = deviceRegistration.task
    deviceRegistration.task = Task {
      await previousRegistration?.value
      guard deviceRegistration.lastMetadata != metadata else { return }
      do {
        _ = try await deviceRegistrationService.register(metadata)
        deviceRegistration.lastMetadata = metadata
        // 앱 재시작 때 복원된 세션도 익명 기기를 소유 계정에 연결한다.
        if await authService.isLoggedIn {
          do {
            try await deviceRegistrationService.linkDeviceToCurrentUser()
          } catch {
            FestiCoreLogger.error(
              "기기 등록 후 계정 바인딩 실패",
              category: .app
            )
          }
        }
      } catch {
        FestiCoreLogger.error("기기 등록 실패: \(error.localizedDescription)", category: .app)
      }
    }
  }
}
