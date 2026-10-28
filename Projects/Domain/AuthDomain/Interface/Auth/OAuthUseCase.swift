//
//  OAuthUseCase.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public protocol OAuthUseCase: Sendable {
  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult
}
