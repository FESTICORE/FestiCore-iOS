//
//  AuthRequestBody.swift
//  APIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import Foundation

public struct AuthLoginBody: Encodable, Sendable {
  public let provider: String
  public let token: String
  public let authorizationCode: String?
  public let name: String?

  public init(
    provider: String,
    token: String,
    authorizationCode: String?,
    name: String?
  ) {
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

  public init(
    nickname: String,
    termsVersion: String,
    pushOptIn: Bool
  ) {
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
