//
//  WebSocketHandshakeInterceptor.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

import Alamofire

/// WebSocket 요청 인터셉터. 인증과 재시도는 HTTP 와 같은 요청별 인터셉터(`base`)에 맡긴다.
///
/// 재시도는 연결이 열리기 전 handshake 재접속에만 쓴다. 열린 연결이 끊긴 뒤 몰래 다시 열면
/// 이전 연결로 보낸 메시지의 응답이 사라지므로, 끊김은 오류로 호출부에 넘긴다.
struct WebSocketHandshakeInterceptor: RequestInterceptor {
  /// handshake 가 끝나 연결이 열렸다는 응답 (101 Switching Protocols)
  private static let switchingProtocols = 101

  /// 요청의 인증 정책과 재시도 정책을 조립한 인터셉터
  let base: any RequestInterceptor

  func adapt(
    _ urlRequest: URLRequest,
    for session: Session,
    completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
  ) {
    return base.adapt(
      urlRequest,
      for: session,
      completion: completion
    )
  }

  func retry(
    _ request: Request,
    for session: Session,
    dueTo error: any Error,
    completion: @escaping @Sendable (RetryResult) -> Void
  ) {
    guard request.response?.statusCode != Self.switchingProtocols else {
      completion(.doNotRetry)
      return
    }
    base.retry(
      request,
      for: session,
      dueTo: error,
      completion: completion
    )
  }
}
