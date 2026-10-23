//
//  ServiceDependencyAssemblyTests.swift
//  ServiceAssemblyTests
//
//  Created by FestiCore on 10/22/26.
//

import Dependencies
import Testing
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
@testable import ServiceAssembly

@Suite("ServiceAssembly")
struct ServiceDependencyAssemblyTests {
  @Test("별도 앱 등록 없이 라이브 의존성을 제공한다")
  func resolvesLiveServicesWithoutAppRegistration() {
    let (networkClient, authService) = withDependencies {
      $0.context = .live
    } operation: {
      @Dependency(\.networkClient) var networkClient
      @Dependency(\.authService) var authService
      return (networkClient, authService)
    }

    #expect((networkClient as AnyObject) === (NetworkContainer.authenticatedClient as AnyObject))
    #expect((authService as AnyObject) === (NetworkContainer.authService as AnyObject))
  }

  @Test("같은 인증 수명주기의 클라이언트와 서비스를 등록한다")
  func registersSharedAuthSession() {
    var values = DependencyValues()
    ServiceDependencyAssembly.register(into: &values)

    #expect((values.networkClient as AnyObject) === (NetworkContainer.authenticatedClient as AnyObject))
    #expect((values.authService as AnyObject) === (NetworkContainer.authService as AnyObject))
  }
}
