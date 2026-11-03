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
  case devices

  public var path: String {
    switch self {
    case .auth: return "api/v1/auth"
    case .me: return "api/v1/me"
    case .festivals: return "api/v1/festivals"
    case .devices: return "api/v1/devices"
    }
  }
}
