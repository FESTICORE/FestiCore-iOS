//
//  NetworkContainer.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/22/26.
//

import FestiCoreAuth
import FestiCoreAuthInterface
import FestiCoreNetwork
import FestiCoreNetworkInterface
import FestiCoreStorage

public enum NetworkContainer {
  private static let assembly = makeAssembly()

  public static var authenticatedClient: any FestiCoreNetworkClient { assembly.authenticatedClient }
  public static var authService: any AuthService { assembly.authService }

  private static func makeAssembly() -> Assembly {
    let auth = AuthFactory.make(
      refreshClient: NetworkClientFactory.plain(),
      storage: StorageFactory.secureStorage
    )
    return Assembly(authenticatedClient: auth.authenticatedClient, authService: auth)
  }
}

private extension NetworkContainer {
  struct Assembly {
    let authenticatedClient: any FestiCoreNetworkClient
    let authService: any AuthService
  }
}
