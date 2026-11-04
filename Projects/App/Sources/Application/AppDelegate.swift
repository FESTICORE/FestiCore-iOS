//
//  AppDelegate.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import UIKit
import ComposableArchitecture
import CoreAssembly
import FestiCoreAnalyticsInterface
import FestiCoreAuthInterface
import ServiceAssembly

@MainActor
class AppDelegate: UIResponder, UIApplicationDelegate {
  var secureStorage = StorageAssembly.secureStorage()
  @Dependency(\.authService) var authService
  @Dependency(\.deviceRegistrationService) var deviceRegistrationService
  @Dependency(\.liveActivityRegistrationService) var liveActivityRegistrationService
  @Dependency(\.analyticsUseCase) var analyticsUseCase
  var deviceRegistration = DeviceRegistrationRuntime()
  var notificationAuthorization = NotificationAuthorizationRuntime()

  @MainActor
  struct DeviceRegistrationRuntime {
    var task: Task<Void, Never>?
    var lastMetadata: DeviceRegistrationMetadata?
    var liveActivityStartToken: String?
    var liveActivityStartTokenTask: Task<Void, Never>?
    var liveActivityTokenSync: LiveActivityTokenSync?
  }

  @MainActor
  struct NotificationAuthorizationRuntime {
    var client = NotificationAuthorizationClient.live
    var task: Task<NotificationPermissionResult, Never>?
    var hasRequestedAPNsRegistration = false
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configure()
    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
  }

  func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {}
}
