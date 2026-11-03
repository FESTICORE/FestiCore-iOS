//
//  AuthRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

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

/// 닉네임만 바꾼다. 약관·알림 동의 값은 보내지 않는다.
public struct AuthNicknameUpdateBody: Encodable, Sendable {
  public let nickname: String

  public init(nickname: String) {
    self.nickname = nickname
  }
}

public enum AuthRequest: FestiCoreDataRequest, Sendable {
  case login(body: AuthLoginBody)
  case refresh(refreshToken: String)
  case logout(sessionID: UUID)
  case me(sessionID: UUID)
  case updateMe(body: AuthProfileUpdateBody, sessionID: UUID)
  case updateNickname(body: AuthNicknameUpdateBody, sessionID: UUID)
  case withdraw(sessionID: UUID)

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .login, .refresh, .logout: return .post
    case .me: return .get
    case .updateMe, .updateNickname: return .patch
    case .withdraw: return .delete
    }
  }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case .login, .refresh: return .none
    case let .logout(sessionID), let .me(sessionID), let .updateMe(_, sessionID),
         let .updateNickname(_, sessionID), let .withdraw(sessionID):
      return .sessionBound(sessionID)
    }
  }

  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .login(body): return body
    case let .refresh(refreshToken): return RefreshBody(refreshToken: refreshToken)
    case let .updateMe(body, _): return body
    case let .updateNickname(body, _): return body
    case .logout, .me, .withdraw: return nil
    }
  }

  private var api: AuthAPI {
    switch self {
    case .login: return .login
    case .refresh: return .refresh
    case .logout: return .logout
    case .me, .updateMe, .updateNickname: return .me
    case .withdraw: return .withdraw
    }
  }
}

private struct RefreshBody: Encodable, Sendable {
  let refreshToken: String
}
