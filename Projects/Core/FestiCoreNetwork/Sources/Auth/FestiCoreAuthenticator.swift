//
//  FestiCoreAuthenticator.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

import FestiCoreNetworkInterface

import Alamofire

/// Alamofire `Authenticator` 구현. 토큰 주입 / refresh / 401 판정을 담당한다.
/// refresh 동시요청 중복 방지(single-flight)는 `AuthenticationInterceptor` 가 처리한다.
final class FestiCoreAuthenticator: Authenticator {
  typealias Credential = FestiCoreCredential

  private let refresher: TokenRefreshing
  private let store: CredentialStore

  init(refresher: TokenRefreshing, store: CredentialStore) {
    self.refresher = refresher
    self.store = store
  }

  /// 요청에 Bearer 토큰 주입.
  func apply(_ credential: FestiCoreCredential, to urlRequest: inout URLRequest) {
    urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
  }

  /// 만료 / 401 시 새 토큰 발급. async refresher 를 completion 으로 연결한다.
  func refresh(
    _ credential: FestiCoreCredential,
    for _: Session,
    completion: @escaping @Sendable (Result<FestiCoreCredential, any Error>) -> Void
  ) {
    guard let context = store.refreshContext(matching: credential) else {
      completion(.failure(StaleRefreshError()))
      return
    }
    Task {
      do {
        let renewed = try await refresher.refresh(credential, sessionID: context.sessionID)
        guard store.replace(renewed, ifCurrent: credential, revision: context.revision) else {
          throw StaleRefreshError()
        }
        completion(.success(renewed))
      } catch {
        completion(.failure(error))
      }
    }
  }

  /// 401 이면 인증 에러로 간주 → refresh 트리거.
  func didRequest(
    _: URLRequest,
    with response: HTTPURLResponse,
    failDueToAuthenticationError _: any Error
  ) -> Bool {
    response.statusCode == 401
  }

  /// 요청의 Authorization 헤더가 현재 credential 토큰과 일치하는지.
  func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: FestiCoreCredential) -> Bool {
    urlRequest.headers["Authorization"] == HTTPHeader.authorization(bearerToken: credential.accessToken).value
  }
}

private struct StaleRefreshError: Error {}
