//
//  AppDelegate+DeviceRegistration.swift
//  FestiCore
//
//  Created by FestiCore on 10/29/26.
//

import UIKit

import CoreAssembly
import FestiCoreLiveActivity
import ServiceAssembly

extension AppDelegate {
  func configureDeviceRegistration() {
    liveActivityStartToken = FestiCoreFestivalLiveActivity.pushToStartToken
    registerDeviceWithStoredAPNsToken()
    UIApplication.shared.registerForRemoteNotifications()
    observeLiveActivityStartToken()
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
      do {
        _ = try await deviceRegistrationService.register(metadata)
      } catch {
        FestiCoreLogger.error("기기 등록 실패: \(error.localizedDescription)", category: .app)
      }
    }
  }
}
