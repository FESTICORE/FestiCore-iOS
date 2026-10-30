//
//  AuthAPI.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

public enum AuthAPI: String, CaseIterable, Sendable {
  case login
  case refresh
  case logout
  case me
  case withdraw

  public var path: String {
    switch self {
    case .login: return "\(FestiCoreDomain.auth.path)/login"
    case .refresh: return "\(FestiCoreDomain.auth.path)/refresh"
    case .logout: return "\(FestiCoreDomain.auth.path)/logout"
    case .me: return FestiCoreDomain.me.path
    case .withdraw: return FestiCoreDomain.me.path
    }
  }
}
