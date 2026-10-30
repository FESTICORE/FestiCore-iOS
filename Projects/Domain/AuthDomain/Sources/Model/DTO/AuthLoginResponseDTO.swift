//
//  AuthLoginResponseDTO.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreNetworkInterface

typealias AuthLoginResponseDTO = BaseResponseDTO<AuthLoginDataDTO>

struct AuthLoginDataDTO: Decodable, Sendable {
  let accessToken: String
  let refreshToken: String
  let newUser: Bool
  let user: AuthUserDTO
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
}
