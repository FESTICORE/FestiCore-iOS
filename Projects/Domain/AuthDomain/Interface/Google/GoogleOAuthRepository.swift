//
//  GoogleOAuthRepository.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public protocol GoogleOAuthRepository: Sendable {
  @MainActor
  func credential() async throws -> AuthCredential
}
