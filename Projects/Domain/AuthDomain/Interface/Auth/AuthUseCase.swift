//
//  AuthUseCase.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public protocol AuthUseCase: Sendable {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult
  func signOut() async throws
}
