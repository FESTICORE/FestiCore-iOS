//
//  DependencyValues+Network.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/23/26.
//

import Dependencies
import FestiCoreAuth
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

extension AuthSessionExpiryDependency: DependencyKey {
  public static var liveValue: AuthSessionExpiryClient { .live() }
}
