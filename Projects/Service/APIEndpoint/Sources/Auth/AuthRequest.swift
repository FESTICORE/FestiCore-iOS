//
//  AuthRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface

public struct AuthLoginBody: Encodable, Sendable {
  public let provider: String
  public let token: String
  public let authorizationCode: String?
  public let name: String?

  public init(provider: String, token: String, authorizationCode: String?, name: String?) {
    self.provider = provider
    self.token = token
    self.authorizationCode = authorizationCode
    self.name = name
  }
}

public enum AuthRequest: FestiCoreDataRequest, Sendable {
  case login(body: AuthLoginBody)
  case refresh(refreshToken: String)
  case logout

  public var path: String {
    switch self {
    case .login: AuthAPI.login.path
    case .refresh: AuthAPI.refresh.path
    case .logout: AuthAPI.logout.path
    }
  }

  public var method: HTTPMethod { .post }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case .login, .refresh: .none
    case .logout: .automatic
    }
  }

  public var maxRetryAttempts: Int { 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .login(body): body
    case let .refresh(refreshToken): RefreshBody(refreshToken: refreshToken)
    case .logout: nil
    }
  }
}

private struct RefreshBody: Encodable, Sendable {
  let refreshToken: String
}
