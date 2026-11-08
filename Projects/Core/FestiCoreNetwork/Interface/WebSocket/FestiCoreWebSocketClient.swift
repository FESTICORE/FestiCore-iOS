import Foundation

/// WebSocket 연결 진입점. HTTP `send` 처럼 요청 타입으로 연결하고, 서비스는 Alamofire 에 의존하지 않는다.
///
///   `let socket = try client.connect(FestivalPackSocketRequest.updates)`
///   `try await socket.send(text)`
///   `let reply = try await socket.receive()`
public protocol FestiCoreWebSocketClient: Sendable {
  /// 요청을 연결로 만든다. baseURL 이 없거나 주소를 만들 수 없으면 `.request(.invalidURL)` 로 즉시 실패한다.
  func connect<R: FestiCoreWebSocketRequest>(_ request: R) throws(FestiCoreNetworkError) -> any FestiCoreWebSocketConnection
}

public protocol FestiCoreWebSocketConnection: Sendable {
  /// 연결이 열린 뒤 텍스트를 한 번 보낸다. 실패해도 자동으로 다시 보내지 않는다.
  func send(_ text: String) async throws
  /// 다음 텍스트 메시지를 기다린다. 연결이 끝나면 원본 전송 오류를 던진다.
  func receive() async throws -> String
  /// 연결을 닫고 기다리던 송수신을 끝낸다.
  func cancel()
}

public enum FestiCoreWebSocketError: Error, Equatable {
  case nonTextMessage
}
