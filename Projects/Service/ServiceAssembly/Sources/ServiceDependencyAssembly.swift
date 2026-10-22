//
//  ServiceDependencyAssembly.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/22/26.
//

import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestiCoreStorage

public enum ServiceDependencyAssembly {
  public static func register(into values: inout DependencyValues) {
    StorageFactory.register(into: &values)
    values.networkClient = NetworkContainer.authenticatedClient
    values.authService = NetworkContainer.authService
  }
}
