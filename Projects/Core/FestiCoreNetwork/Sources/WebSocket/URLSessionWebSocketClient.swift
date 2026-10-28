import Foundation
import FestiCoreNetworkInterface

/// URLSession 기반 WebSocket 전송. 상위 서비스는 텍스트 메시지만 사용한다.
public final class URLSessionWebSocketClient: FestiCoreWebSocketClient, @unchecked Sendable {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func connect(to url: URL) -> any FestiCoreWebSocketConnection {
    URLSessionWebSocketConnection(task: session.webSocketTask(with: url))
  }
}

private final class URLSessionWebSocketConnection: FestiCoreWebSocketConnection, @unchecked Sendable {
  private let task: URLSessionWebSocketTask

  init(task: URLSessionWebSocketTask) {
    self.task = task
    task.resume()
  }

  func send(_ text: String) async throws {
    try await task.send(.string(text))
  }

  func receive() async throws -> String {
    switch try await task.receive() {
    case .string(let text): return text
    case .data: throw FestiCoreWebSocketError.nonTextMessage
    @unknown default: throw FestiCoreWebSocketError.nonTextMessage
    }
  }

  func cancel() {
    task.cancel(with: .goingAway, reason: nil)
  }
}
