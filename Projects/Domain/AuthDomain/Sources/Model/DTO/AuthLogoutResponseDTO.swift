//
//  AuthLogoutResponseDTO.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreNetworkInterface

typealias AuthLogoutResponseDTO = BaseResponseDTO<AuthLogoutDataDTO>

struct AuthLogoutDataDTO: Decodable, Sendable {
  let success: Bool
}
