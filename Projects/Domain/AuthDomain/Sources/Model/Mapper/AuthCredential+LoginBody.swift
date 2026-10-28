//
//  AuthCredential+LoginBody.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import APIEndpoint
import AuthDomainInterface
import Foundation

extension AuthCredential {
  var loginBody: AuthLoginBody {
    switch self {
    case let .google(idToken, serverAuthCode):
      return AuthLoginBody(
        provider: "google",
        token: idToken,
        authorizationCode: serverAuthCode,
        name: nil
      )
    case let .apple(idToken, authorizationCode, name):
      return AuthLoginBody(
        provider: "apple",
        token: idToken,
        authorizationCode: authorizationCode,
        name: Self.normalizedAppleName(name)
      )
    }
  }

  private static func normalizedAppleName(_ name: String?) -> String? {
    guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
      return nil
    }

    var result = ""
    var length = 0
    for character in name {
      let characterLength = String(character).utf16.count
      guard length + characterLength <= 30 else { break }
      result.append(character)
      length += characterLength
    }
    return result.isEmpty ? nil : result
  }
}
