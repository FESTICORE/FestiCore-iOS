import Foundation
import FestiCoreNetworkInterface

/// URLSession 기반 WebSocket 전송. 상위 서비스는 텍스트 메시지만 사용한다.
public final class URLSessionWebSocketClient: FestiCoreWebSocketClient, @unchecked Sendable {
  private let session: URLSession
  private let delegate: WebSocketSessionDelegate?
  private let monitor: WebSocketMonitor
  private let ownsSession: Bool

  public convenience init() {
    self.init(configuration: SessionFactory.webSocketConfiguration, monitor: WebSocketMonitor())
  }

  /// 외부 세션을 쓰는 호출부를 위한 진입점. 세션 delegate는 호출부가 관리한다.
  public init(session: URLSession) {
    self.session = session
    self.delegate = nil
    self.monitor = WebSocketMonitor()
    self.ownsSession = false
  }

  init(configuration: URLSessionConfiguration, monitor: WebSocketMonitor) {
    let delegate = WebSocketSessionDelegate()
    self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    self.delegate = delegate
    self.monitor = monitor
    self.ownsSession = true
  }

  deinit {
    if ownsSession {
      session.finishTasksAndInvalidate()
    }
  }

  public func connect(to url: URL) -> any FestiCoreWebSocketConnection {
    let task = session.webSocketTask(with: url)
    let state = WebSocketConnectionState(id: task.taskIdentifier, monitor: monitor)
    delegate?.register(task: task, state: state)
    monitor.record(.attempted(id: state.id))
    return URLSessionWebSocketConnection(task: task, state: state, monitor: monitor)
  }
}

protocol WebSocketTask: Sendable {
  var closeCode: URLSessionWebSocketTask.CloseCode { get }
  func resume()
  func send(_ message: URLSessionWebSocketTask.Message) async throws
  func receive() async throws -> URLSessionWebSocketTask.Message
  func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketTask: WebSocketTask {}

final class WebSocketConnectionState: @unchecked Sendable {
  let id: Int
  private let monitor: WebSocketMonitor
  private let lock = NSLock()
  private var locallyCancelled = false
  private var terminalReported = false

  init(id: Int, monitor: WebSocketMonitor) {
    self.id = id
    self.monitor = monitor
  }

  func cancel() {
    lock.lock()
    locallyCancelled = true
    lock.unlock()
    reportClose(code: URLSessionWebSocketTask.CloseCode.goingAway.rawValue)
  }

  func reportClose(code: Int) {
    lock.lock()
    defer { lock.unlock() }
    guard !terminalReported else { return }
    terminalReported = true
    if code == URLSessionWebSocketTask.CloseCode.normalClosure.rawValue
      || code == URLSessionWebSocketTask.CloseCode.goingAway.rawValue
    {
      monitor.record(.closed(id: id, code: code))
    } else {
      monitor.record(.failed(id: id, domain: "WebSocketClose", code: code, status: nil))
    }
  }

  func reportFailure(_ error: Error, status: Int? = nil) {
    lock.lock()
    defer { lock.unlock() }
    guard !terminalReported else { return }
    terminalReported = true
    let wasCancelled = locallyCancelled
    if wasCancelled {
      monitor.record(.closed(id: id, code: URLSessionWebSocketTask.CloseCode.goingAway.rawValue))
    } else {
      let nsError = error as NSError
      // Error domains are identifiers, but third-party domains may embed user data.
      let domain = [NSURLErrorDomain, NSPOSIXErrorDomain].contains(nsError.domain)
        ? nsError.domain : "Other"
      monitor.record(.failed(id: id, domain: domain, code: nsError.code, status: status))
    }
  }

  func monitorOpened() {
    lock.lock()
    defer { lock.unlock() }
    if !terminalReported {
      monitor.record(.opened(id: id))
    }
  }
}

final class URLSessionWebSocketConnection: FestiCoreWebSocketConnection, @unchecked Sendable {
  private let task: any WebSocketTask
  private let state: WebSocketConnectionState
  private let monitor: WebSocketMonitor

  init(task: any WebSocketTask, state: WebSocketConnectionState, monitor: WebSocketMonitor) {
    self.task = task
    self.state = state
    self.monitor = monitor
    task.resume()
  }

  func send(_ text: String) async throws {
    do {
      try await task.send(.string(text))
      monitor.record(.sent(id: state.id))
    } catch {
      reportTransportError(error)
      throw error
    }
  }

  func receive() async throws -> String {
    let message: URLSessionWebSocketTask.Message
    do {
      message = try await task.receive()
    } catch {
      reportTransportError(error)
      throw error
    }
    switch message {
    case .string(let text):
      monitor.record(.received(id: state.id))
      return text
    case .data:
      monitor.record(.nonText(id: state.id))
      throw FestiCoreWebSocketError.nonTextMessage
    @unknown default:
      monitor.record(.nonText(id: state.id))
      throw FestiCoreWebSocketError.nonTextMessage
    }
  }

  func cancel() {
    state.cancel()
    task.cancel(with: .goingAway, reason: nil)
  }

  private func reportTransportError(_ error: Error) {
    let closeCode = task.closeCode
    if closeCode != .invalid {
      state.reportClose(code: closeCode.rawValue)
    } else {
      let status = ((task as? URLSessionWebSocketTask)?.response as? HTTPURLResponse)?.statusCode
      state.reportFailure(error, status: status)
    }
  }
}

final class WebSocketSessionDelegate: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var states: [Int: WebSocketConnectionState] = [:]

  func register(task: URLSessionWebSocketTask, state: WebSocketConnectionState) {
    lock.lock()
    states[task.taskIdentifier] = state
    lock.unlock()
  }

  func state(for task: URLSessionTask, remove: Bool = false) -> WebSocketConnectionState? {
    lock.lock()
    let state = remove ? states.removeValue(forKey: task.taskIdentifier) : states[task.taskIdentifier]
    lock.unlock()
    return state
  }

  func urlSession(
    _: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol _: String?
  ) {
    state(for: webSocketTask)?.monitorOpened()
  }

  func urlSession(
    _: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason _: Data?
  ) {
    state(for: webSocketTask)?.reportClose(code: closeCode.rawValue)
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let state = state(for: task, remove: true) else { return }
    if let error {
      state.reportFailure(error, status: (task.response as? HTTPURLResponse)?.statusCode)
    } else {
      let code = (task as? URLSessionWebSocketTask)?.closeCode.rawValue
        ?? URLSessionWebSocketTask.CloseCode.normalClosure.rawValue
      state.reportClose(code: code)
    }
  }
}
