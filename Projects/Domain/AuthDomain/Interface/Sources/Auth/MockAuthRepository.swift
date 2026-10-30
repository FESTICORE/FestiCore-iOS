//
//  MockAuthRepository.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import IssueReporting

public struct MockAuthRepository: AuthInterface {
  private let dependencyName: String

  public init(dependencyName: String = "authRepository") {
    self.dependencyName = dependencyName
  }

  public func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    reportIssue("\(dependencyName) 미등록")
    throw AuthDomainError.configurationMissing
  }

  public func fetchProfile() async throws -> AuthProfile {
    reportIssue("\(dependencyName) 미등록")
    throw AuthDomainError.configurationMissing
  }

  public func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    reportIssue("\(dependencyName) 미등록")
    throw AuthDomainError.configurationMissing
  }

  public func signOut() async throws {
    reportIssue("\(dependencyName) 미등록")
    throw AuthDomainError.configurationMissing
  }

  public func withdraw() async throws {
    reportIssue("\(dependencyName) 미등록")
    throw AuthDomainError.configurationMissing
  }
}
