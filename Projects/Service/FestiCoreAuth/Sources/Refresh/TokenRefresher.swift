//
//  TokenRefresher.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreAPIEndpoint
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
      let response = try await client.send(
        AuthRequest.refresh(refreshToken: current.refreshToken),
        as: RefreshEnvelope.self
      )
      guard response.code == "SUCCESS" else {
        throw FestiCoreNetworkError.decoding(.failed(UnexpectedResponseCode(code: response.code)))
      }
      return FestiCoreCredential(
        accessToken: response.data.accessToken,
        refreshToken: response.data.refreshToken,
        expiresAt: JWTDecoder.decodeExpiration(response.data.accessToken)
      )
    } catch {
      let networkError = (error as? FestiCoreNetworkError) ?? .decoding(.failed(error))
      if case let .response(response) = networkError, response.isUnauthorized {
        await onAuthFailure(current)
      }
      throw networkError
    }
  }
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
