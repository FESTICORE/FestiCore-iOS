//
//  AuthServiceDependency.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies

public enum AuthServiceDependency: TestDependencyKey {
  public static var testValue: any AuthService { UnimplementedAuthService() }
}

public extension DependencyValues {
  var authService: any AuthService {
    get { self[AuthServiceDependency.self] }
    set { self[AuthServiceDependency.self] = newValue }
  }
}

private struct UnimplementedAuthService: AuthService {
  var isLoggedIn: Bool { get async { fatalError("authService 미등록") } }
  var refreshToken: String? { get async { fatalError("authService 미등록") } }
  func signIn(accessToken: String, refreshToken: String) async { fatalError("authService 미등록") }
  func signOut() async { fatalError("authService 미등록") }
}
