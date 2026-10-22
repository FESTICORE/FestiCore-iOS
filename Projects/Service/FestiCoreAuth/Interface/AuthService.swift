//
//  AuthService.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreNetworkInterface
import Dependencies

public protocol AuthService: Sendable {
  var isLoggedIn: Bool { get async }
  var refreshToken: String? { get async }
  func signIn(accessToken: String, refreshToken: String) async
  func signOut() async
}

public protocol AuthenticatedClientProvider: Sendable {
  var authenticatedClient: any FestiCoreNetworkClient { get }
}

public extension Notification.Name {
  static let festiCoreAuthSessionDidExpire = Notification.Name("festicore.auth.session.didExpire")
}

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
