//
//  AppDelegate.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import UIKit
import ComposableArchitecture
import CoreAssembly
import ServiceAssembly

class AppDelegate: UIResponder, UIApplicationDelegate {
  let secureStorage = StorageAssembly.secureStorage()
  @Dependency(\.deviceRegistrationService) var deviceRegistrationService
  var registrationTask: Task<Void, Never>?

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
    UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {}
}
