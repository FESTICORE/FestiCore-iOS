//
//  AuthLoginRequest.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Alamofire
import FestiCoreAuthDomainInterface
import FestiCoreNetworkInterface
import Foundation

struct AuthLoginRequest: FestiCoreDataRequest {
  typealias Response = AuthLoginResponseDTO

  let credential: AuthCredential

  var path: String { "api/v1/auth/login" }
  var method: HTTPMethod { .post }
  var authorization: FestiCoreAuthorization { .none }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { AuthLoginBody(credential: credential) }
}

struct AuthLoginBody: Encodable, Sendable {
  let provider: String
  let token: String
  let authorizationCode: String?
  let name: String?

  init(credential: AuthCredential) {
    switch credential {
    case let .google(idToken, serverAuthCode):
      provider = "google"
      token = idToken
      authorizationCode = serverAuthCode
      name = nil
    case let .apple(idToken, code, name):
      provider = "apple"
      token = idToken
      authorizationCode = code
      self.name = Self.normalizedAppleName(name)
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
