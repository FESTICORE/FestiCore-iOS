//
//  DependencyValues+DeviceRegistration.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies
import FestiCoreDeviceInterface

extension DeviceRegistrationServiceDependency: DependencyKey {
  public static var liveValue: any DeviceRegistrationService {
    NetworkContainer.deviceRegistrationService
  }
}
