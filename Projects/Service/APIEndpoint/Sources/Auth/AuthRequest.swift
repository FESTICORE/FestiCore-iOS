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
  case withdraw

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .login, .refresh, .logout: return .post
    case .withdraw: return .delete
    }
  }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case .login, .refresh: return .none
    case .logout, .withdraw: return .automatic
    }
  }

  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .login(body): return body
    case let .refresh(refreshToken): return RefreshBody(refreshToken: refreshToken)
    case .logout, .withdraw: return nil
    }
  }

  private var api: AuthAPI {
    switch self {
    case .login: return .login
    case .refresh: return .refresh
    case .logout: return .logout
    case .withdraw: return .withdraw
    }
  }
}

private struct RefreshBody: Encodable, Sendable {
  let refreshToken: String
}
