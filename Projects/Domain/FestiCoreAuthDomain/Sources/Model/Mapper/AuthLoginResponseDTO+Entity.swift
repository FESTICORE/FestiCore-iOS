//
//  AuthLoginResponseDTO+Entity.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreAuthDomainInterface

extension AuthLoginDataDTO {
  var result: AuthLoginResult {
    AuthLoginResult(newUser: newUser, user: user.entity)
  }
}

extension AuthUserDTO {
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
