//
//  AuthDomainError+Network.swift
//  AuthDomain
//

import AuthDomainInterface
import FestiCoreNetworkInterface

extension AuthDomainError {
  init?(networkError: FestiCoreNetworkError?) {
    guard let networkError else { return nil }
    switch networkError {
    case let .response(response) where response.isUnauthorized:
      self = .notAuthenticated
    case let .response(response) where response.httpStatus == 422 && response.code == "TERMS_VERSION_OUTDATED":
      self = .termsOutdated
    case .transport(.notConnected), .transport(.timedOut):
      self = .offline
    case .request, .response, .transport, .decoding:
      self = .invalidResponse
    }
  }
}
