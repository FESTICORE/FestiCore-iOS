//
//  DependencyValues+LiveActivity.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies
import FestiCoreDeviceInterface

extension LiveActivityRegistrationServiceDependency: DependencyKey {
  public static var liveValue: any LiveActivityRegistrationService {
    NetworkContainer.liveActivityRegistrationService
  }
}
