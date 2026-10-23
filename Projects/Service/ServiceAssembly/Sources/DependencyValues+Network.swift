//
//  DependencyValues+Network.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/23/26.
//

import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface

extension NetworkClientDependency: DependencyKey {
  public static var liveValue: any FestiCoreNetworkClient {
    NetworkContainer.authenticatedClient
  }
}

extension AuthServiceDependency: DependencyKey {
  public static var liveValue: any AuthService {
    NetworkContainer.authService
  }
}
