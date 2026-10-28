//
//  AppleOAuthCredentialMapper.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreAuthDomainInterface
import Foundation

enum AppleOAuthCredentialMapper {
  static func map(
    identityToken: Data?,
    authorizationCode: Data?,
    fullName: PersonNameComponents?
  ) throws -> AuthCredential {
    guard let identityToken,
          let token = String(data: identityToken, encoding: .utf8),
          !token.isEmpty else {
      throw AuthDomainError.missingIDToken
    }
    guard let authorizationCode,
          let code = String(data: authorizationCode, encoding: .utf8),
          !code.isEmpty else {
      throw AuthDomainError.missingAuthorizationCode
    }

    let name = fullName.map {
      PersonNameComponentsFormatter().string(from: $0)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return .apple(idToken: token, authorizationCode: code, name: name.flatMap { $0.isEmpty ? nil : $0 })
  }
}
