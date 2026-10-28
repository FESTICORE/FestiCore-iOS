//
//  MockGoogleOAuthRepository.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import IssueReporting

public struct MockGoogleOAuthRepository: GoogleOAuthInterface {
  public init() {}

  @MainActor
  public func credential() async throws -> AuthCredential {
    reportIssue("googleOAuthRepository 미등록")
    throw AuthDomainError.configurationMissing
  }
}
