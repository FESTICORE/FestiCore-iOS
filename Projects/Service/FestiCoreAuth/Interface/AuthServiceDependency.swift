//
//  AuthServiceDependency.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies
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

  func signIn(accessToken: String, refreshToken: String) async {
    reportIssue("authService 미등록")
  }

  func signOut() async {
    reportIssue("authService 미등록")
  }
}
