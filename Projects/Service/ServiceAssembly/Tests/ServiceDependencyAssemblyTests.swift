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
  @Test("같은 인증 수명주기의 클라이언트와 서비스를 등록한다")
  func registersSharedAuthSession() {
    var values = DependencyValues()
    ServiceDependencyAssembly.register(into: &values)

    #expect((values.networkClient as AnyObject) === (NetworkContainer.authenticatedClient as AnyObject))
    #expect((values.authService as AnyObject) === (NetworkContainer.authService as AnyObject))
  }
}
