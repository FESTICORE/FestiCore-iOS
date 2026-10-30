//
//  AuthProfileDataDTO+.swift
//  AuthDomain
//
//  Created by FestiCore on 10/31/26.
//

import AuthDomainInterface

extension AuthProfileDataDTO {
  func toDomain() -> AuthProfile {
    AuthProfile(user: AuthUser(
      id: id, provider: provider, email: email, nickname: nickname,
      nicknameConfirmed: nicknameConfirmed, termsAcceptedAt: termsAcceptedAt,
      termsVersion: termsVersion, pushOptIn: pushOptIn, profileImageURL: profileImageUrl
    ), currentTermsVersion: currentTermsVersion)
  }
}
