//
//  AuthLogoutResponseDTO.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

struct AuthLogoutResponseDTO: Decodable, Sendable {
  let code: String
  let data: AuthLogoutDataDTO
}

struct AuthLogoutDataDTO: Decodable, Sendable {
  let success: Bool
}
