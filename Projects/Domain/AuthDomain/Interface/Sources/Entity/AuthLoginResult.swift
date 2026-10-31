//
//  AuthLoginResult.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Foundation

public struct AuthLoginResult: Sendable, Equatable {
  public let newUser: Bool
  public let user: AuthUser
  /// 확정 전 임시 세션의 식별자. 비밀 값이 아니며 코디네이터가 확정·폐기할 때 쓴다.
  public let sessionID: UUID?

  public init(newUser: Bool, user: AuthUser, sessionID: UUID? = nil) {
    self.newUser = newUser
    self.user = user
    self.sessionID = sessionID
  }
}
