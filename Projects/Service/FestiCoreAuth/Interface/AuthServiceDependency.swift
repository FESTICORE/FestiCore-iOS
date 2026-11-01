//
//  AuthServiceDependency.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies
import Foundation
import IssueReporting

public enum AuthServiceDependency: TestDependencyKey {
  public static var testValue: any AuthService {
    return UnimplementedAuthService()
  }
}

public extension DependencyValues {
  var authService: any AuthService {
    get {
      return self[AuthServiceDependency.self]
    }
    set { self[AuthServiceDependency.self] = newValue }
  }
}

private struct UnimplementedAuthService: AuthService {
  var isLoggedIn: Bool {
    get async {
      reportIssue("authService 미등록")
      return false
    }
  }

  var refreshToken: String? {
    get async {
      reportIssue("authService 미등록")
      return nil
    }
  }

  var currentUserID: String? {
    get async { nil }
  }

  var sessionID: UUID {
    get async {
      reportIssue("authService 미등록")
      return UUID()
    }
  }

  var authenticatedSessionID: UUID? {
    get async {
      reportIssue("authService 미등록")
      return nil
    }
  }

  var hasPendingLocalClear: Bool {
    get async {
      reportIssue("authService 미등록")
      return false
    }
  }

  var hasUnconfirmedRevocation: Bool {
    get async {
      reportIssue("authService 미등록")
      return false
    }
  }

  var hasPendingSignOutCleanup: Bool {
    get async {
      reportIssue("authService 미등록")
      return false
    }
  }

  var hasPendingWithdrawalAuthorizationCleanup: Bool {
    get async {
      reportIssue("authService 미등록")
      return false
    }
  }

  var hasPendingWithdrawalCleanup: Bool {
    get async {
      reportIssue("authService 미등록")
      return false
    }
  }

  func stageSession(accessToken: String, refreshToken: String) async -> UUID {
    reportIssue("authService 미등록")
    return UUID()
  }

  func commitSession(_ id: UUID) async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func rememberUserID(_ userID: String) async {
    // Test doubles can omit the optional local identity cache.
  }

  func signOut() async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func signOut(ifSessionIDMatches _: UUID) async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func prepareRevocation(_: AuthRevocationKind, ifSessionIDMatches _: UUID) async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func finishRevocationRequest() async {
    reportIssue("authService 미등록")
  }

  func confirmSignOut() async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func confirmWithdrawalAuthorizationRejected() async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func retryUnconfirmedLocalCleanup() async -> Bool {
    reportIssue("authService 미등록")
    return false
  }

  func completeWithdrawal() async -> Bool {
    reportIssue("authService 미등록")
    return false
  }
}
