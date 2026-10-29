import Foundation
import Darwin
import Testing

@testable import FestiCoreNetwork
import FestiCoreNetworkInterface

@Suite("WebSocket 전송")
struct WebSocketTransportTests {
  @Test("WebSocket handshake는 공통 Accept 헤더를 사용한다")
  func handshakeUsesDefaultHeaders() {
    let headers = SessionFactory.webSocketConfiguration.httpAdditionalHeaders
    let accept = headers?.first { String(describing: $0.key).lowercased() == "accept" }?.value as? String

    #expect(accept == "application/json")
  }

  @Test("실제 WebSocket handshake의 non-101 응답은 상태와 원본 오류를 전달한다", arguments: [401, 200])
  func rejectsNonUpgradeHandshake(statusCode: Int) async throws {
    let server = try LoopbackHandshakeServer(statusCode: statusCode)
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let configuration = SessionFactory.webSocketConfiguration
    configuration.timeoutIntervalForRequest = 5
    let client = URLSessionWebSocketClient(configuration: configuration, monitor: monitor)
    let connection = client.connect(to: server.url)

    do {
      _ = try await connection.receive()
      Issue.record("non-101 handshake는 실패해야 한다")
    } catch let error as URLError {
      #expect(error.code == .badServerResponse)
    } catch {
      Issue.record("예상하지 않은 handshake 오류: \(error)")
    }

    let recorded = events.values
    #expect(recorded.count == 2)
    guard case .attempted(let id) = recorded.first,
          case .failed(let failedID, let domain, let code, let status) = recorded.last
    else {
      Issue.record("연결 시도와 오류 이벤트가 필요함: \(recorded)")
      return
    }
    #expect(failedID == id)
    #expect(domain == NSURLErrorDomain)
    #expect(code == URLError.badServerResponse.rawValue)
    #expect(status == statusCode)
    #expect(server.requestHeaders?.contains("Accept: application/json") == true)
    #expect(!String(describing: recorded).contains("private-path"))
    #expect(!String(describing: recorded).contains("token=secret"))
  }

  @Test("텍스트 송수신은 원문을 전달하고 본문 없이 이벤트를 기록한다")
  func textMessages() async throws {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let task = StubWebSocketTask(receiveResult: .success(.string("private-response")))
    let connection = URLSessionWebSocketConnection(
      task: task,
      state: WebSocketConnectionState(id: 12, monitor: monitor),
      monitor: monitor
    )

    try await connection.send("private-request")
    let received = try await connection.receive()

    #expect(task.didResume)
    #expect(task.sentText == "private-request")
    #expect(received == "private-response")
    #expect(events.values == [.sent(id: 12), .received(id: 12)])
    #expect(!String(describing: events.values).contains("private-"))
  }

  @Test("바이너리 메시지는 공개 WebSocket 오류로 거절한다")
  func binaryMessage() async {
    let events = RecordedWebSocketEvents()
    let connection = makeConnection(
      task: StubWebSocketTask(receiveResult: .success(.data(Data([1, 2, 3])))),
      events: events
    )

    do {
      _ = try await connection.receive()
      Issue.record("바이너리 메시지는 거절해야 한다")
    } catch let error as FestiCoreWebSocketError {
      #expect(error == .nonTextMessage)
    } catch {
      Issue.record("예상하지 않은 오류: \(error)")
    }
    #expect(events.values == [.nonText(id: 42)])
  }

  @Test("전송 오류를 감싸지 않고 원본으로 전달한다")
  func originalSendError() async {
    let original = WebSocketMarkerError()
    let events = RecordedWebSocketEvents()
    let connection = makeConnection(task: StubWebSocketTask(sendError: original), events: events)

    do {
      try await connection.send("secret-body")
      Issue.record("전송 오류가 전달되어야 한다")
    } catch let error as WebSocketMarkerError {
      #expect(error === original)
    } catch {
      Issue.record("원본 오류가 아님: \(error)")
    }
    #expect(events.values.count == 1)
    #expect(!String(describing: events.values).contains("secret-body"))
  }

  @Test("수신 오류를 감싸지 않고 원본으로 전달한다")
  func originalReceiveError() async {
    let original = WebSocketMarkerError()
    let events = RecordedWebSocketEvents()
    let connection = makeConnection(
      task: StubWebSocketTask(receiveResult: .failure(original)),
      events: events
    )

    do {
      _ = try await connection.receive()
      Issue.record("수신 오류가 전달되어야 한다")
    } catch let error as WebSocketMarkerError {
      #expect(error === original)
    } catch {
      Issue.record("원본 오류가 아님: \(error)")
    }
    #expect(events.values.count == 1)
  }

  @Test("정상 종료 코드가 먼저 설정되면 수신 오류보다 종료 이벤트를 기록한다")
  func normalCloseWinsReceiveError() async {
    let original = POSIXError(.ENOTCONN)
    let events = RecordedWebSocketEvents()
    let connection = makeConnection(
      task: StubWebSocketTask(
        receiveResult: .failure(original),
        closeCode: .normalClosure
      ),
      events: events
    )

    do {
      _ = try await connection.receive()
      Issue.record("수신 오류가 전달되어야 한다")
    } catch let error as POSIXError {
      #expect(error.code == .ENOTCONN)
    } catch {
      Issue.record("원본 POSIX 오류가 아님: \(error)")
    }
    #expect(events.values == [.closed(id: 42, code: URLSessionWebSocketTask.CloseCode.normalClosure.rawValue)])
  }

  @Test("재연결 판단에 쓰는 URL·POSIX 오류 타입을 그대로 전달한다")
  func retryableTransportErrorsRemainTyped() async {
    for original in [
      NSError(domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue),
      NSError(domain: NSPOSIXErrorDomain, code: 54)
    ] {
      let events = RecordedWebSocketEvents()
      let connection = makeConnection(
        task: StubWebSocketTask(receiveResult: .failure(original)),
        events: events
      )

      do {
        _ = try await connection.receive()
        Issue.record("전송 오류가 전달되어야 한다")
      } catch {
        #expect((error as NSError) === original)
      }
      #expect(events.values == [.failed(id: 42, domain: original.domain, code: original.code, status: nil)])
    }
  }

  @Test("로컬 취소가 먼저 오면 늦은 오류와 종료는 정상 종료 한 번만 기록한다")
  func cancelBeforeFailure() {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let state = WebSocketConnectionState(id: 23, monitor: monitor)

    state.cancel()
    state.reportFailure(URLError(.cancelled))
    state.reportClose(code: URLSessionWebSocketTask.CloseCode.normalClosure.rawValue)

    #expect(events.values == [.closed(id: 23, code: URLSessionWebSocketTask.CloseCode.goingAway.rawValue)])
  }

  @Test("오류가 먼저 오면 늦은 취소와 종료가 오류를 덮지 않는다")
  func failureBeforeCancel() {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let state = WebSocketConnectionState(id: 24, monitor: monitor)

    state.reportFailure(URLError(.notConnectedToInternet), status: 503)
    state.cancel()
    state.reportClose(code: URLSessionWebSocketTask.CloseCode.goingAway.rawValue)

    #expect(events.values == [.failed(id: 24, domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue, status: 503)])
  }

  @Test("동시 종료 보고도 연결당 하나의 종료 이벤트만 남긴다")
  func concurrentTerminalReports() async {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let state = WebSocketConnectionState(id: 25, monitor: monitor)

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<40 {
        group.addTask {
          if index.isMultiple(of: 2) {
            state.reportClose(code: 1000)
          } else {
            state.reportFailure(URLError(.networkConnectionLost))
          }
        }
      }
    }

    #expect(events.values.count == 1)
  }

  @Test("취소는 대기 중 수신을 해제하고 정상 종료 한 번만 기록한다")
  func cancelReleasesPendingReceive() async {
    let events = RecordedWebSocketEvents()
    let task = StubWebSocketTask(receiveResult: nil)
    let connection = makeConnection(task: task, events: events)
    let receiving = Task { try await connection.receive() }
    await task.waitUntilReceiving()

    connection.cancel()
    do {
      _ = try await receiving.value
      Issue.record("취소한 수신은 종료되어야 한다")
    } catch let error as URLError {
      #expect(error.code == .cancelled)
    } catch {
      Issue.record("예상하지 않은 취소 오류: \(error)")
    }

    #expect(task.cancelCode == .goingAway)
    #expect(events.values == [.closed(id: 42, code: URLSessionWebSocketTask.CloseCode.goingAway.rawValue)])
  }

  @Test("오류 이벤트에는 URL·헤더·본문·close reason이 포함되지 않는다")
  func monitorRedactsSensitiveValues() {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let state = WebSocketConnectionState(id: 31, monitor: monitor)
    let original = NSError(domain: "private-host/path?token=secret", code: 7, userInfo: [
      NSLocalizedDescriptionKey: "Bearer private-access private-body private-reason"
    ])

    monitor.record(.attempted(id: 31))
    state.monitorOpened()
    state.reportFailure(original, status: 401)

    #expect(events.values == [
      .attempted(id: 31),
      .opened(id: 31),
      .failed(id: 31, domain: "Other", code: 7, status: 401)
    ])
    let output = String(describing: events.values)
    for secret in ["private-host", "token=secret", "private-access", "private-body", "private-reason"] {
      #expect(!output.contains(secret))
    }
  }

  @Test("delegate 완료는 task 상태를 제거하고 늦은 오류를 중복 기록하지 않는다")
  func delegateCompletionReleasesState() {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let delegate = WebSocketSessionDelegate()
    let session = URLSession(configuration: .ephemeral)
    let task = session.webSocketTask(with: URL(string: "wss://private-host.test/path?token=secret")!)
    let state = WebSocketConnectionState(id: task.taskIdentifier, monitor: monitor)
    delegate.register(task: task, state: state)

    delegate.urlSession(session, task: task, didCompleteWithError: URLError(.networkConnectionLost))
    state.reportFailure(URLError(.cancelled))

    #expect(delegate.state(for: task) == nil)
    #expect(events.values == [
      .failed(id: task.taskIdentifier, domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue, status: nil)
    ])
    #expect(!String(describing: events.values).contains("private-host"))
  }

  @Test("정상 close 이벤트는 reason을 기록하지 않고 완료 시 상태를 제거한다")
  func delegateNormalClose() {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let delegate = WebSocketSessionDelegate()
    let session = URLSession(configuration: .ephemeral)
    let task = session.webSocketTask(with: URL(string: "wss://private-host.test/")!)
    let state = WebSocketConnectionState(id: task.taskIdentifier, monitor: monitor)
    delegate.register(task: task, state: state)

    delegate.urlSession(
      session,
      webSocketTask: task,
      didCloseWith: .normalClosure,
      reason: Data("private-close-reason".utf8)
    )
    delegate.urlSession(session, task: task, didCompleteWithError: nil)

    #expect(delegate.state(for: task) == nil)
    #expect(events.values == [.closed(id: task.taskIdentifier, code: URLSessionWebSocketTask.CloseCode.normalClosure.rawValue)])
    #expect(!String(describing: events.values).contains("private-close-reason"))
  }

  @Test("비정상 close는 오류로 한 번만 기록한다")
  func abnormalClose() {
    let events = RecordedWebSocketEvents()
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    let state = WebSocketConnectionState(id: 32, monitor: monitor)

    state.reportClose(code: 1008)
    state.reportFailure(URLError(.networkConnectionLost))

    #expect(events.values == [.failed(id: 32, domain: "WebSocketClose", code: 1008, status: nil)])
  }

  private func makeConnection(task: StubWebSocketTask, events: RecordedWebSocketEvents) -> URLSessionWebSocketConnection {
    let monitor = WebSocketMonitor(recorder: { events.record($0) })
    return URLSessionWebSocketConnection(
      task: task,
      state: WebSocketConnectionState(id: 42, monitor: monitor),
      monitor: monitor
    )
  }
}

private final class RecordedWebSocketEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [WebSocketMonitor.Event] = []

  func record(_ event: WebSocketMonitor.Event) {
    lock.withLock { recorded.append(event) }
  }

  var values: [WebSocketMonitor.Event] {
    lock.withLock { recorded }
  }
}

private final class WebSocketMarkerError: Error, @unchecked Sendable {}

/// 한 번의 HTTP handshake에 고정 응답을 보내는 로컬 서버. 외부 네트워크에 의존하지 않는다.
private final class LoopbackHandshakeServer: @unchecked Sendable {
  let url: URL
  private let listener: Int32
  private let statusCode: Int
  private let lock = NSLock()
  private var capturedHeaders: String?

  var requestHeaders: String? { lock.withLock { capturedHeaders } }

  init(statusCode: Int) throws {
    let listener = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard listener >= 0 else { throw POSIXError(.EIO) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: in_addr_t(0x7f000001).bigEndian)
    let bound = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bound == 0, Darwin.listen(listener, 1) == 0 else {
      Darwin.close(listener)
      throw POSIXError(.EADDRINUSE)
    }

    var localAddress = sockaddr_in()
    var localLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let named = withUnsafeMutablePointer(to: &localAddress) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.getsockname(listener, $0, &localLength)
      }
    }
    guard named == 0 else {
      Darwin.close(listener)
      throw POSIXError(.EIO)
    }

    self.listener = listener
    self.statusCode = statusCode
    self.url = URL(string: "ws://127.0.0.1:\(UInt16(bigEndian: localAddress.sin_port))/private-path?token=secret")!
    DispatchQueue.global().async { [self] in serveOneHandshake() }
  }

  deinit {
    Darwin.shutdown(listener, SHUT_RDWR)
    Darwin.close(listener)
  }

  private func serveOneHandshake() {
    var descriptor = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
    guard Darwin.poll(&descriptor, 1, 5_000) > 0 else { return }
    let client = Darwin.accept(listener, nil, nil)
    guard client >= 0 else { return }
    defer { Darwin.close(client) }

    var bytes = [UInt8](repeating: 0, count: 2_048)
    var request = Data()
    while request.count < 16_384 {
      let count = Darwin.read(client, &bytes, bytes.count)
      guard count > 0 else { return }
      request.append(bytes, count: count)
      if request.range(of: Data("\r\n\r\n".utf8)) != nil { break }
    }
    lock.withLock { capturedHeaders = String(data: request, encoding: .utf8) }

    let reason = statusCode == 401 ? "Unauthorized" : "OK"
    let response = Data("HTTP/1.1 \(statusCode) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
    response.withUnsafeBytes { buffer in
      guard let base = buffer.baseAddress else { return }
      var sent = 0
      while sent < buffer.count {
        let count = Darwin.write(client, base.advanced(by: sent), buffer.count - sent)
        guard count > 0 else { return }
        sent += count
      }
    }
  }
}

private final class StubWebSocketTask: WebSocketTask, @unchecked Sendable {
  private let lock = NSLock()
  private let sendError: Error?
  private let receiveResult: Result<URLSessionWebSocketTask.Message, Error>?
  private var pendingReceive: CheckedContinuation<URLSessionWebSocketTask.Message, Error>?
  private var receiveStarted: CheckedContinuation<Void, Never>?
  private var receiving = false
  private var resumed = false
  private var message: URLSessionWebSocketTask.Message?
  private var storedCloseCode: URLSessionWebSocketTask.CloseCode

  init(
    receiveResult: Result<URLSessionWebSocketTask.Message, Error>? = .success(.string("")),
    sendError: Error? = nil,
    closeCode: URLSessionWebSocketTask.CloseCode = .invalid
  ) {
    self.receiveResult = receiveResult
    self.sendError = sendError
    self.storedCloseCode = closeCode
  }

  func resume() {
    lock.withLock { resumed = true }
  }

  func send(_ message: URLSessionWebSocketTask.Message) async throws {
    lock.withLock { self.message = message }
    if let sendError { throw sendError }
  }

  func receive() async throws -> URLSessionWebSocketTask.Message {
    if let receiveResult { return try receiveResult.get() }
    return try await withCheckedThrowingContinuation { continuation in
      let started = lock.withLock { () -> CheckedContinuation<Void, Never>? in
        pendingReceive = continuation
        receiving = true
        let started = receiveStarted
        receiveStarted = nil
        return started
      }
      started?.resume()
    }
  }

  func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason _: Data?) {
    let pending = lock.withLock { () -> CheckedContinuation<URLSessionWebSocketTask.Message, Error>? in
      self.storedCloseCode = closeCode
      let pending = pendingReceive
      pendingReceive = nil
      return pending
    }
    pending?.resume(throwing: URLError(.cancelled))
  }

  func waitUntilReceiving() async {
    await withCheckedContinuation { continuation in
      let ready = lock.withLock { () -> Bool in
        if receiving { return true }
        receiveStarted = continuation
        return false
      }
      if ready { continuation.resume() }
    }
  }

  var didResume: Bool { lock.withLock { resumed } }

  var sentText: String? {
    lock.withLock {
      if case .string(let text) = message { return text }
      return nil
    }
  }

  var closeCode: URLSessionWebSocketTask.CloseCode { lock.withLock { storedCloseCode } }
  var cancelCode: URLSessionWebSocketTask.CloseCode? {
    let code = closeCode
    return code == .invalid ? nil : code
  }
}
