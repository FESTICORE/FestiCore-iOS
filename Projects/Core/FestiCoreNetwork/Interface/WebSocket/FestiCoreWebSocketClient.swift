import Foundation

/// 연결 생성과 메시지 전송을 분리해 서비스가 URLSession에 의존하지 않게 한다.
public protocol FestiCoreWebSocketClient: Sendable {
  func connect(to url: URL) -> any FestiCoreWebSocketConnection
}

public protocol FestiCoreWebSocketConnection: Sendable {
  func send(_ text: String) async throws
  func receive() async throws -> String
  func cancel()
}

public enum FestiCoreWebSocketError: Error, Equatable {
  case nonTextMessage
}
