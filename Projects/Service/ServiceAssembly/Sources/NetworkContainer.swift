//
//  NetworkContainer.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/22/26.
//

import CoreAssembly
import FestiCoreAuth
import FestiCoreAuthInterface
import FestiCoreDevice
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface

public enum NetworkContainer {
  private static let assembly = makeAssembly()

  public static var authenticatedClient: any FestiCoreNetworkClient { assembly.authenticatedClient }
  public static var authService: any AuthService { assembly.authService }
  public static var liveActivityRegistrationService: any LiveActivityRegistrationService {
    assembly.liveActivityRegistrationService
  }

  private static func makeAssembly() -> Assembly {
    let auth = AuthFactory.make(
      refreshClient: NetworkAssembly.plainClient(),
      storage: StorageAssembly.secureStorage()
    )
    return Assembly(
      authenticatedClient: auth.authenticatedClient,
      authService: auth,
      liveActivityRegistrationService: NetworkLiveActivityRegistrationService(client: auth.authenticatedClient)
    )
  }
}

private extension NetworkContainer {
  struct Assembly {
    let authenticatedClient: any FestiCoreNetworkClient
    let authService: any AuthService
    let liveActivityRegistrationService: any LiveActivityRegistrationService
  }
}
