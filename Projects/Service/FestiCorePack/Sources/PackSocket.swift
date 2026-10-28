import Foundation

protocol PackSocket: Sendable {
  func send(_ text: String) async throws
  func receive() async throws -> String
  func cancel()
}

final class URLSessionPackSocket: PackSocket, @unchecked Sendable {
  private let task: URLSessionWebSocketTask

  init(url: URL, session: URLSession) {
    task = session.webSocketTask(with: url)
    task.resume()
  }

  func send(_ text: String) async throws {
    try await task.send(.string(text))
  }

  func receive() async throws -> String {
    switch try await task.receive() {
    case .string(let text): return text
    case .data: throw PackSyncError.invalidMessage
    @unknown default: throw PackSyncError.invalidMessage
    }
  }

  func cancel() {
    task.cancel(with: .goingAway, reason: nil)
  }
}
