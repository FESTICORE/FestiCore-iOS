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
import FestiCoreFestivalCatalog
import FestiCoreFestivalCatalogInterface
import FestiCoreNetworkInterface
import FestiCoreNetwork
import FestiCorePack
import FestiCorePackInterface
import Foundation

public enum NetworkContainer {
  private static let assembly = makeAssembly()

  public static var authenticatedClient: any FestiCoreNetworkClient { assembly.authenticatedClient }
  public static var authService: any AuthService { assembly.authService }
  public static var liveActivityRegistrationService: any LiveActivityRegistrationService {
    assembly.liveActivityRegistrationService
  }
  public static var deviceRegistrationService: any DeviceRegistrationService {
    assembly.deviceRegistrationService
  }
  public static var packSyncService: any PackSyncService { assembly.packSyncService }
  public static var festivalCatalogService: any FestivalCatalogService { assembly.festivalCatalogService }

  private static func makeAssembly() -> Assembly {
    let storage = StorageAssembly.secureStorage()
    let auth = AuthFactory.make(
      refreshClient: NetworkAssembly.plainClient(),
      storage: storage
    )
    return Assembly(
      authenticatedClient: auth.authenticatedClient,
      authService: auth,
      deviceRegistrationService: NetworkDeviceRegistrationService(client: auth.authenticatedClient, storage: storage),
      liveActivityRegistrationService: NetworkLiveActivityRegistrationService(client: auth.authenticatedClient),
      packSyncService: NetworkPackSyncService(
        baseURL: NetworkClientFactory.bundleBaseURL,
        cacheDirectory: packCacheDirectory
      ),
      festivalCatalogService: NetworkFestivalCatalogService(
        client: NetworkAssembly.plainClient(),
        cacheURL: packCacheDirectory.deletingLastPathComponent().appendingPathComponent("festival-catalog.json"),
        baseURL: NetworkClientFactory.bundleBaseURL
      )
    )
  }

  private static var packCacheDirectory: URL {
    let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Library/Application Support", isDirectory: true)
    return applicationSupport.appendingPathComponent("FestiCore/Packs", isDirectory: true)
  }
}

private extension NetworkContainer {
  struct Assembly {
    let authenticatedClient: any FestiCoreNetworkClient
    let authService: any AuthService
    let deviceRegistrationService: any DeviceRegistrationService
    let liveActivityRegistrationService: any LiveActivityRegistrationService
    let packSyncService: any PackSyncService
    let festivalCatalogService: any FestivalCatalogService
  }
}
