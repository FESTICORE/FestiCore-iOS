//
//  AuthorizingInterceptor.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation
import FestiCoreNetworkInterface

import Alamofire

/// 공유 `AuthenticationInterceptor` 를 감싸, credential 유무로 인증 파이프라인을 우회하는 조건부 래퍼.
/// 비로그인 상태에서 인터셉터가 `missingCredential` 로 요청을 실패시키는 걸 막는다.
struct AuthorizingInterceptor: RequestInterceptor {
  let base: AuthenticationInterceptor<FestiCoreAuthenticator>
  let store: any CredentialStore
  var expectedSessionID: UUID?

  func bound(to sessionID: UUID) -> Self {
    Self(base: base, store: store, expectedSessionID: sessionID)
  }

  private func matches(_ request: URLRequest) -> Bool {
    guard let expectedSessionID else { return true }
    guard let snapshot = store.sessionSnapshot(), snapshot.id == expectedSessionID else { return false }
    return request.value(forHTTPHeaderField: "Authorization") == "Bearer \(snapshot.credential.accessToken)"
  }

  func adapt(
    _ urlRequest: URLRequest,
    for session: Session,
    completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
  ) {
    if let expectedSessionID, store.sessionSnapshot()?.id != expectedSessionID {
      completion(.failure(SessionBoundAuthorizationError()))
      return
    }
    guard base.credential != nil else {
      if expectedSessionID != nil {
        completion(.failure(SessionBoundAuthorizationError()))
        return
      }
      completion(.success(urlRequest))
      return
    }
    base.adapt(urlRequest, for: session) { result in
      switch result {
      case let .success(adapted):
        completion(self.matches(adapted) ? .success(adapted) : .failure(SessionBoundAuthorizationError()))
      case let .failure(error):
        completion(.failure(error))
      }
    }
  }

  func retry(
    _ request: Request,
    for session: Session,
    dueTo error: any Error,
    completion: @escaping @Sendable (RetryResult) -> Void
  ) {
    if let expectedSessionID, store.sessionSnapshot()?.id != expectedSessionID {
      completion(.doNotRetry)
      return
    }
    guard base.credential != nil else {
      completion(.doNotRetry)
      return
    }
    base.retry(request, for: session, dueTo: error) { result in
      guard let expectedSessionID = self.expectedSessionID else {
        completion(result)
        return
      }
      completion(self.store.sessionSnapshot()?.id == expectedSessionID ? result : .doNotRetry)
    }
  }
}

private struct SessionBoundAuthorizationError: Error {}
