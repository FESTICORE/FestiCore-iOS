//
//  AuthInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public protocol AuthInterface: Sendable {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult
  func signOut() async throws
}

public enum AuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any AuthInterface { MockAuthRepository() }
  public static var previewValue: any AuthInterface { testValue }
}

public extension DependencyValues {
  var authRepository: any AuthInterface {
    get { self[AuthRepositoryDependency.self] }
    set { self[AuthRepositoryDependency.self] = newValue }
  }
}
