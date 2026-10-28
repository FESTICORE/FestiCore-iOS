//
//  GoogleOAuthInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public protocol GoogleOAuthInterface: Sendable {
  @MainActor
  func credential() async throws -> AuthCredential
}

public enum GoogleOAuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any GoogleOAuthInterface { MockGoogleOAuthRepository() }
  public static var previewValue: any GoogleOAuthInterface { testValue }
}

public extension DependencyValues {
  var googleOAuthRepository: any GoogleOAuthInterface {
    get { self[GoogleOAuthRepositoryDependency.self] }
    set { self[GoogleOAuthRepositoryDependency.self] = newValue }
  }
}
