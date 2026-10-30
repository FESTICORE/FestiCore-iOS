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

public struct AuthProfileUpdateBody: Encodable, Sendable {
  public let nickname: String
  public let acceptTerms: AcceptTerms
  public let pushOptIn: Bool

  public init(nickname: String, termsVersion: String, pushOptIn: Bool) {
    self.nickname = nickname
    self.acceptTerms = AcceptTerms(version: termsVersion)
    self.pushOptIn = pushOptIn
  }

  public struct AcceptTerms: Encodable, Sendable {
    public let version: String
  }
}

public enum AuthRequest: FestiCoreDataRequest, Sendable {
  case login(body: AuthLoginBody)
  case refresh(refreshToken: String)
  case logout
  case me
  case updateMe(body: AuthProfileUpdateBody)
  case withdraw

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .login, .refresh, .logout: return .post
    case .me: return .get
    case .updateMe: return .patch
    case .withdraw: return .delete
    }
  }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case .login, .refresh: return .none
    case .logout, .me, .updateMe, .withdraw: return .automatic
    }
  }

  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .login(body): return body
    case let .refresh(refreshToken): return RefreshBody(refreshToken: refreshToken)
    case let .updateMe(body): return body
    case .logout, .me, .withdraw: return nil
    }
  }

  private var api: AuthAPI {
    switch self {
    case .login: return .login
    case .refresh: return .refresh
    case .logout: return .logout
    case .me, .updateMe: return .me
    case .withdraw: return .withdraw
    }
  }
}

private struct RefreshBody: Encodable, Sendable {
  let refreshToken: String
}
