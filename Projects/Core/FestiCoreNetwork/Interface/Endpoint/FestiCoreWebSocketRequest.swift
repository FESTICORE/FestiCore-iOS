//
//  FestiCoreWebSocketRequest.swift
//  FestiCoreNetworkInterface
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

import Alamofire

/// WebSocket 연결 요청. HTTP 요청처럼 `path`·`authorization`·`maxRetryAttempts` 를 `FestiCoreEndpoint` 로 선언하고,
/// 클라이언트가 baseURL 의 https 를 wss 로 바꿔 연결한다.
///
/// `maxRetryAttempts` 는 연결이 열리기 전 handshake 재접속 횟수다.
/// 열린 연결이 끊기면 다시 열지 않고, 보낸 메시지도 다시 보내지 않는다. 재전송은 메시지 뜻을 아는 호출부가 정한다.
public protocol FestiCoreWebSocketRequest: FestiCoreEndpoint {}

public extension FestiCoreWebSocketRequest {
  /// WebSocket handshake 는 GET 이다.
  var method: HTTPMethod {
    return .get
  }
}
