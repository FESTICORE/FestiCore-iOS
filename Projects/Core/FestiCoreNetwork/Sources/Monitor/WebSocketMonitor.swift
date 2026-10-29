import Foundation
import FestiCoreLogger

/// WebSocket 이벤트에는 주소, 헤더, 본문, 종료 사유를 넣지 않는다.
struct WebSocketMonitor: Sendable {
  enum Event: Equatable, Sendable {
    case attempted(id: Int)
    case opened(id: Int)
    case sent(id: Int)
    case received(id: Int)
    case nonText(id: Int)
    case closed(id: Int, code: Int)
    case failed(id: Int, domain: String, code: Int, status: Int?)
  }

  private let recorder: @Sendable (Event) -> Void

  init(recorder: @escaping @Sendable (Event) -> Void = { event in WebSocketMonitor.log(event) }) {
    self.recorder = recorder
  }

  func record(_ event: Event) {
    recorder(event)
  }

  private static func log(_ event: Event) {
    switch event {
    case .attempted(let id):
      FestiCoreLogger.debug("WebSocket #\(id) connecting", category: .network)
    case .opened(let id):
      FestiCoreLogger.debug("WebSocket #\(id) connected", category: .network)
    case .sent(let id):
      FestiCoreLogger.debug("WebSocket #\(id) text sent", category: .network)
    case .received(let id):
      FestiCoreLogger.debug("WebSocket #\(id) text received", category: .network)
    case .nonText(let id):
      FestiCoreLogger.notice("WebSocket #\(id) non-text message rejected", category: .network)
    case .closed(let id, let code):
      FestiCoreLogger.notice("WebSocket #\(id) closed code=\(code)", category: .network)
    case .failed(let id, let domain, let code, let status):
      let statusText = status.map(String.init) ?? "none"
      FestiCoreLogger.error(
        "WebSocket #\(id) failed domain=\(domain) code=\(code) status=\(statusText)",
        category: .network
      )
    }
  }
}
