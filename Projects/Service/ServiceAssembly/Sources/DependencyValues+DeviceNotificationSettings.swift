//
//  DependencyValues+DeviceNotificationSettings.swift
//  ServiceAssembly
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCoreDeviceInterface

extension DeviceNotificationSettingsServiceDependency: DependencyKey {
  public static var liveValue: any DeviceNotificationSettingsService {
    NetworkContainer.deviceNotificationSettingsService
  }
}
