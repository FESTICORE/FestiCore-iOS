//
//  FestiCoreDomain.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

public enum FestiCoreDomain: Sendable {
  case auth
  case me
  case festivals
  case flags
  case bearer
  case notices
  case legal

  public var path: String {
    switch self {
    case .auth: return "api/v1/auth"
    case .me: return "api/v1/me"
    case .festivals: return "api/v1/festivals"
    case .flags: return "api/v1/flags"
    case .bearer: return "api/v1/bearer"
    case .notices: return "api/v1/notices"
    case .legal: return "api/v1/legal"
  }
}
}
