//
//  FestiCoreDomain.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

public enum FestiCoreDomain: Sendable {
  case auth
  case me
  case flags
  case bearer

  public var path: String {
    switch self {
    case .auth: return "api/v1/auth"
    case .me: return "api/v1/me"
    case .flags: return "api/v1/flags"
    case .bearer: return "api/v1/bearer"
    }
  }
}
