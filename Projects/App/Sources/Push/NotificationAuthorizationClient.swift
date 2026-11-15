//
//  NotificationAuthorizationClient.swift
//  FestiCore
//
//  Created by FestiCore on 11/15/26.
//

import UIKit
import UserNotifications

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
      return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    },
    requestAuthorization: {
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    },
    registerForRemoteNotifications: {
      UIApplication.shared.registerForRemoteNotifications()
    }
  )
}
