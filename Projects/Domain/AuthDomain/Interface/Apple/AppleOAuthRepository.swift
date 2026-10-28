//
//  AppleOAuthRepository.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public protocol AppleOAuthRepository: Sendable {
  @MainActor
  func credential() async throws -> AuthCredential
}
