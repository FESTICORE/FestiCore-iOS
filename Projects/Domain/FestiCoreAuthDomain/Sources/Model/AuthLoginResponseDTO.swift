//
//  AuthLoginResponseDTO.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreAuthDomainInterface

struct AuthLoginResponseDTO: Decodable, Sendable {
  let code: String
  let data: AuthLoginDataDTO
}

struct AuthLoginDataDTO: Decodable, Sendable {
  let accessToken: String
  let refreshToken: String
  let newUser: Bool
  let user: AuthUserDTO

  var result: AuthLoginResult {
    AuthLoginResult(newUser: newUser, user: user.entity)
  }
}

struct AuthUserDTO: Decodable, Sendable {
  let id: String
  let provider: String
  let email: String?
  let nickname: String?
  let nicknameConfirmed: Bool
  let termsAcceptedAt: String?
  let termsVersion: String?
  let pushOptIn: Bool
  let profileImageUrl: String?

  var entity: AuthUser {
    AuthUser(
      id: id,
      provider: provider,
      email: email,
      nickname: nickname,
      nicknameConfirmed: nicknameConfirmed,
      termsAcceptedAt: termsAcceptedAt,
      termsVersion: termsVersion,
      pushOptIn: pushOptIn,
      profileImageURL: profileImageUrl
    )
  }
}
