//
//  OAuthUseCaseInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public protocol OAuthUseCaseInterface: Sendable {
  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult
}

public enum OAuthUseCaseDependency: TestDependencyKey {
  public static var testValue: any OAuthUseCaseInterface { MockOAuthUseCase() }
  public static var previewValue: any OAuthUseCaseInterface { testValue }
}

public extension DependencyValues {
  var oauthUseCase: any OAuthUseCaseInterface {
    get { self[OAuthUseCaseDependency.self] }
    set { self[OAuthUseCaseDependency.self] = newValue }
  }
}
