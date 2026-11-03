//
//  FestivalNotificationPermissionClient+Live.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface
import UserNotifications

extension FestivalNotificationPermissionClient: DependencyKey {
  public static let liveValue = Self(status: {
    switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
    case .authorized, .provisional, .ephemeral: return .allowed
    case .denied: return .denied
    default: return .notDetermined
    }
  })
}
