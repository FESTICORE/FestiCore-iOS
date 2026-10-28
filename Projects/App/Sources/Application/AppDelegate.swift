//
//  AppDelegate.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import UIKit
import Dependencies
import FestiCoreDeviceInterface
import FestiCoreLogger

class AppDelegate: UIResponder, UIApplicationDelegate {
  @Dependency(\.context) private var dependencyContext
  @Dependency(\.deviceRegistrationService) private var deviceRegistrationService
  private var registrationTask: Task<Void, Never>?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configure()
    registerDevice(apnsToken: nil)
    application.registerForRemoteNotifications()
    return true
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    registerDevice(apnsToken: apnsToken)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    FestiCoreLogger.error("APNs 토큰 등록 실패: \(error.localizedDescription)", category: .app)
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {}

  private func registerDevice(apnsToken: String?) {
    guard case .live = dependencyContext else { return }

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
