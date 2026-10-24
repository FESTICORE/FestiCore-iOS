//
//  AuthService.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

public protocol AuthService: Sendable {
  var isLoggedIn: Bool { get async }
  var refreshToken: String? { get async }
  func signIn(accessToken: String, refreshToken: String) async
  func signOut() async
}

public extension Notification.Name {
  static let festiCoreAuthSessionDidExpire = Notification.Name("festicore.auth.session.didExpire")
}
