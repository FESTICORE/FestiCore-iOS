//
//  AppleOAuthInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public protocol AppleOAuthInterface: Sendable {
  @MainActor
  func credential() async throws -> AuthCredential
}

public enum AppleOAuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any AppleOAuthInterface { MockAppleOAuthRepository() }
  public static var previewValue: any AppleOAuthInterface { testValue }
}

public extension DependencyValues {
  var appleOAuthRepository: any AppleOAuthInterface {
    get { self[AppleOAuthRepositoryDependency.self] }
    set { self[AppleOAuthRepositoryDependency.self] = newValue }
  }
}
