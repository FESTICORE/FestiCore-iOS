//
//  OAuthUseCaseImpl.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import FestiCoreAuthDomainInterface

public struct OAuthUseCaseImpl: OAuthUseCase {
  @Dependency(\.googleOAuthRepository) private var googleRepository
  @Dependency(\.appleOAuthRepository) private var appleRepository
  @Dependency(\.authUseCase) private var authUseCase

  public init() {}

  public func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    let credential: AuthCredential
    switch provider {
    case .google:
      credential = try await googleRepository.credential()
    case .apple:
      credential = try await appleRepository.credential()
    }
    return try await authUseCase.signIn(with: credential)
  }
}
