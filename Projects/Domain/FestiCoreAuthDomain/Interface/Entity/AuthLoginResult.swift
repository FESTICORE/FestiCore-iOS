//
//  AuthLoginResult.swift
//  FestiCoreAuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public struct AuthLoginResult: Sendable, Equatable {
  public let newUser: Bool
  public let user: AuthUser

  public init(newUser: Bool, user: AuthUser) {
    self.newUser = newUser
    self.user = user
  }
}
