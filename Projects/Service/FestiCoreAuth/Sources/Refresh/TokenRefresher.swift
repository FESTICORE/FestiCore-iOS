//
//  TokenRefresher.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import APIEndpoint
import FestiCoreNetworkInterface

struct TokenRefresher: TokenRefreshing {
  private let client: any FestiCoreRequestClient
  private let sessionIDForCredential: @Sendable (FestiCoreCredential) -> UUID?
  private let onAuthFailure: @Sendable (FestiCoreCredential, UUID) async -> Void

  init(
    client: any FestiCoreRequestClient,
    sessionIDForCredential: @escaping @Sendable (FestiCoreCredential) -> UUID?,
    onAuthFailure: @escaping @Sendable (FestiCoreCredential, UUID) async -> Void
  ) {
    self.client = client
    self.sessionIDForCredential = sessionIDForCredential
    self.onAuthFailure = onAuthFailure
  }

  func refresh(_ current: FestiCoreCredential) async throws(FestiCoreNetworkError) -> FestiCoreCredential {
    let sessionID = sessionIDForCredential(current)
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
      if case let .response(response) = networkError, response.isUnauthorized, let sessionID {
        await onAuthFailure(current, sessionID)
      }
      throw networkError
    }
  }
}

private typealias RefreshEnvelope = BaseResponseDTO<TokenPair>

private struct TokenPair: Decodable, Sendable {
  let accessToken: String
  let refreshToken: String
}

private struct UnexpectedResponseCode: Error {
  let code: String
}
