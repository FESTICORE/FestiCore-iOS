//
//  TokenRefresher.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import Alamofire
import FestiCoreNetworkInterface

struct TokenRefresher: TokenRefreshing {
  private let client: any FestiCoreRequestClient
  private let onAuthFailure: @Sendable (FestiCoreCredential) async -> Void

  init(
    client: any FestiCoreRequestClient,
    onAuthFailure: @escaping @Sendable (FestiCoreCredential) async -> Void
  ) {
    self.client = client
    self.onAuthFailure = onAuthFailure
  }

  func refresh(_ current: FestiCoreCredential) async throws(FestiCoreNetworkError) -> FestiCoreCredential {
    do {
      let response = try await client.send(RefreshRequest(refreshToken: current.refreshToken))
      guard response.code == "SUCCESS" else {
        throw FestiCoreNetworkError.decoding(.failed(UnexpectedResponseCode(code: response.code)))
      }
      return FestiCoreCredential(
        accessToken: response.data.accessToken,
        refreshToken: response.data.refreshToken,
        expiresAt: JWTDecoder.decodeExpiration(response.data.accessToken)
      )
    } catch {
      if case let .response(response) = error, response.isUnauthorized {
        await onAuthFailure(current)
      }
      throw error
    }
  }
}

private struct RefreshRequest: FestiCoreDataRequest, Sendable {
  typealias Response = RefreshEnvelope
  let refreshToken: String

  var path: String { "api/v1/auth/refresh" }
  var method: HTTPMethod { .post }
  var authorization: FestiCoreAuthorization { .none }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { RefreshBody(refreshToken: refreshToken) }
}

private struct RefreshBody: Encodable, Sendable {
  let refreshToken: String
}

private struct RefreshEnvelope: Decodable, Sendable {
  let code: String
  let data: TokenPair
  let message: String
}

private struct TokenPair: Decodable, Sendable {
  let accessToken: String
  let refreshToken: String
}

private struct UnexpectedResponseCode: Error {
  let code: String
}
