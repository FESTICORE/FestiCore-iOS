//
//  AppDelegate.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import UIKit
import Dependencies
import FestiCoreDeviceInterface
import OSLog

class AppDelegate: UIResponder, UIApplicationDelegate {
  @Dependency(\.deviceRegistrationService) private var deviceRegistrationService
  private let logger = Logger(subsystem: "io.festiCore.co", category: "DeviceRegistration")

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configure()
    registerDevice()
    return true
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

  private func registerDevice() {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    guard let configuration = AppConfiguration(infoDictionary: infoDictionary) else {
      logger.error("기기 등록 건너뜀: FestiCoreEnvironment 또는 FestiCoreAPIHost 설정이 유효하지 않음")
      return
    }
    guard let appVersion = infoDictionary["CFBundleShortVersionString"] as? String, !appVersion.isEmpty else {
      logger.error("기기 등록 건너뜀: CFBundleShortVersionString 설정이 유효하지 않음")
      return
    }

    let metadata = DeviceRegistrationMetadata(
      apnsEnvironment: configuration.environment.apnsEnvironment,
      apnsToken: nil,
      appVersion: appVersion,
      osVersion: UIDevice.current.systemVersion,
      locale: Locale.current.identifier,
      timezone: TimeZone.current.identifier
    )

    Task {
      do {
        _ = try await deviceRegistrationService.register(metadata)
      } catch {
        logger.error("기기 등록 실패: \(error.localizedDescription)")
      }
    }
  }
}
