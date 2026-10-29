//
//  MockOAuthUseCase.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import IssueReporting

public struct MockOAuthUseCase: OAuthUseCaseInterface {
  public init() {}

  public func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    reportIssue("oauthUseCase 미등록")
    throw AuthDomainError.configurationMissing
  }
}
