//
//  AuthLoginDataDTO+.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface

extension AuthLoginDataDTO {
  func toDomain() -> AuthLoginResult {
    AuthLoginResult(newUser: newUser, user: user.toDomain())
  }
}

extension AuthUserDTO {
  func toDomain() -> AuthUser {
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
