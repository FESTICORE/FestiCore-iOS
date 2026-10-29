//
//  MockAppleOAuthRepository.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import IssueReporting

public struct MockAppleOAuthRepository: AppleOAuthInterface {
  public init() {}

  @MainActor
  public func credential() async throws -> AuthCredential {
    reportIssue("appleOAuthRepository 미등록")
    throw AuthDomainError.configurationMissing
  }
}
