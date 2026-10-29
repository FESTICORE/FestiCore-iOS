//
//  AuthUseCaseImpl.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import AuthDomainInterface

public struct AuthUseCaseImpl: AuthUseCaseInterface {
  @Dependency(\.authRepository) private var repository

  public init() {}

  public func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    try await repository.signIn(with: credential)
  }

  public func signOut() async throws {
    try await repository.signOut()
  }

  public func withdraw() async throws {
    try await repository.withdraw()
  }
}
