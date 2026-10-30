//
//  AuthUseCaseInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public protocol AuthUseCaseInterface: Sendable {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult
  func fetchProfile() async throws -> AuthProfile
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser
  func signOut() async throws
  func withdraw() async throws
}

extension MockAuthRepository: AuthUseCaseInterface {}

public enum AuthUseCaseDependency: TestDependencyKey {
  public static var testValue: any AuthUseCaseInterface { MockAuthRepository(dependencyName: "authUseCase") }
  public static var previewValue: any AuthUseCaseInterface { testValue }
}

public extension DependencyValues {
  var authUseCase: any AuthUseCaseInterface {
    get { self[AuthUseCaseDependency.self] }
    set { self[AuthUseCaseDependency.self] = newValue }
  }
}
