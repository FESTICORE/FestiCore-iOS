//
//  ServiceDependencyAssemblyTests.swift
//  ServiceAssemblyTests
//
//  Created by FestiCore on 10/22/26.
//

import Dependencies
import Testing
import FestiCoreAuthInterface
import FestiCoreDevice
import FestiCoreDeviceInterface
import FestiCoreFestivalCatalog
import FestiCoreFestivalCatalogInterface
import FestiCoreNetworkInterface
import FestiCorePack
import FestiCorePackInterface
@testable import ServiceAssembly

@Suite("ServiceAssembly")
struct ServiceDependencyAssemblyTests {
  @Test("별도 앱 등록 없이 라이브 의존성을 제공한다")
  func resolvesLiveServicesWithoutAppRegistration() {
    let (networkClient, authService, deviceService, liveActivityService, packService, catalogService) = withDependencies {
      $0.context = .live
    } operation: {
      @Dependency(\.networkClient) var networkClient
      @Dependency(\.authService) var authService
      @Dependency(\.deviceRegistrationService) var deviceService
      @Dependency(\.liveActivityRegistrationService) var liveActivityService
      @Dependency(\.packSyncService) var packService
      @Dependency(\.festivalCatalogService) var catalogService
      return (networkClient, authService, deviceService, liveActivityService, packService, catalogService)
    }

    #expect((networkClient as AnyObject) === (NetworkContainer.authenticatedClient as AnyObject))
    #expect((authService as AnyObject) === (NetworkContainer.authService as AnyObject))
    #expect(deviceService is NetworkDeviceRegistrationService)
    #expect(liveActivityService is NetworkLiveActivityRegistrationService)
    #expect(packService is NetworkPackSyncService)
    #expect(catalogService is NetworkFestivalCatalogService)
  }

  @Test("같은 인증 수명주기의 클라이언트와 서비스를 등록한다")
  func registersSharedAuthSession() {
    var values = DependencyValues()
    ServiceDependencyAssembly.register(into: &values)

    #expect((values.networkClient as AnyObject) === (NetworkContainer.authenticatedClient as AnyObject))
    #expect((values.authService as AnyObject) === (NetworkContainer.authService as AnyObject))
    #expect(values.liveActivityRegistrationService is NetworkLiveActivityRegistrationService)
    #expect(values.deviceRegistrationService is NetworkDeviceRegistrationService)
    #expect(values.packSyncService is NetworkPackSyncService)
    #expect(values.festivalCatalogService is NetworkFestivalCatalogService)
  }
}
