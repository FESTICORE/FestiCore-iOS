//
//  ServiceDependencyAssembly.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/22/26.
//

import Dependencies
import CoreAssembly
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreFestivalCatalogInterface
import FestiCoreNetworkInterface
import FestiCorePackInterface

public enum ServiceDependencyAssembly {
  public static func register(into values: inout DependencyValues) {
    values.registerLiveServices()
  }
}

public extension DependencyValues {
  mutating func registerLiveServices() {
    StorageAssembly.register(into: &self)
    networkClient = NetworkContainer.authenticatedClient
    authService = NetworkContainer.authService
    deviceRegistrationService = NetworkContainer.deviceRegistrationService
    liveActivityRegistrationService = NetworkContainer.liveActivityRegistrationService
    packSyncService = NetworkContainer.packSyncService
    festivalCatalogService = NetworkContainer.festivalCatalogService
  }
}
