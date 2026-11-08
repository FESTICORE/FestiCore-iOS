//
//  WebSocketTransportTests.swift
//  FestiCoreNetworkTests
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation
import Testing

@_spi(WebSocket) import Alamofire
@testable import FestiCoreNetwork
import FestiCoreNetworkInterface

/// Alamofire 세션 위의 WebSocket 연결을 로컬 서버(`LoopbackWebSocketServer`)로 확인한다. 외부 네트워크는 쓰지 않는다.
@Suite(
  "WebSocket 전송",
  .timeLimit(.minutes(1))
)
struct WebSocketTransportTests {
  // MARK: - 연결과 송수신

  @Test("요청 경로·헤더로 ws handshake 를 하고 텍스트를 주고받는다")
  func textRoundTrip() async throws {
    let server = try LoopbackWebSocketServer([.accept([.echo, .waitForClientClose])])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest())

    try await connection.send("hello")
    let reply = try await connection.receive()
    connection.cancel()

    #expect(reply == "hello")
    #expect(server.messages == ["hello"])
    let handshake = try #require(server.handshakes.first)
    #expect(handshake.hasPrefix("GET /socket/updates HTTP/1.1"))
    #expect(handshake.lowercased().contains("accept: application/json"))
    #expect(handshake.contains("X-Socket-Test: on"))
  }

  @Test("연결이 열리기 전에 보낸 메시지는 열린 뒤 한 번만 보낸다")
  func sendWaitsUntilOpen() async throws {
    let server = try LoopbackWebSocketServer([.accept([.receiveText, .sendText("ack"), .waitForClientClose])])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest())

    // connect 직후 handshake 가 끝나기 전에 바로 보낸다.
    try await connection.send("early")
    let reply = try await connection.receive()
    connection.cancel()

    #expect(reply == "ack")
    #expect(server.messages == ["early"])
  }

  @Test("서버가 먼저 보낸 메시지를 받고, 취소하면 going away 로 닫는다")
  func cancelClosesWithGoingAway() async throws {
    let server = try LoopbackWebSocketServer([.accept([.sendText("first"), .waitForClientClose])])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest())

    let first = try await connection.receive()
    connection.cancel()
    try await waitUntil { !server.clientCloseCodes.isEmpty }

    #expect(first == "first")
    #expect(server.clientCloseCodes == [UInt16(URLSessionWebSocketTask.CloseCode.goingAway.rawValue)])
    do {
      _ = try await connection.receive()
      Issue.record("취소한 연결의 수신은 끝나야 한다")
    } catch is CancellationError {
    } catch {
      Issue.record("취소 오류가 아님: \(type(of: error))")
    }
  }

  @Test("바이너리 메시지는 공개 WebSocket 오류로 거절하고 연결은 이어진다")
  func binaryMessageIsRejected() async throws {
    let server = try LoopbackWebSocketServer([.accept([.sendBinary([1, 2, 3]), .sendText("after"), .waitForClientClose])])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest())

    await #expect(throws: FestiCoreWebSocketError.nonTextMessage) {
      _ = try await connection.receive()
    }
    let next = try await connection.receive()
    connection.cancel()

    #expect(next == "after")
  }

  @Test("서버가 닫으면 그 전에 받은 메시지를 먼저 돌려주고 ENOTCONN 으로 끝낸다")
  func serverCloseAfterMessage() async throws {
    let server = try LoopbackWebSocketServer([.accept([
      .sendText("bye"),
      .close(
        code: 1000,
        reason: "private-reason"
      )
    ])])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest())

    let last = try await connection.receive()
    #expect(last == "bye")
    do {
      _ = try await connection.receive()
      Issue.record("닫힌 연결의 수신은 끝나야 한다")
    } catch let error as POSIXError {
      #expect(error.code == .ENOTCONN)
    } catch {
      Issue.record("ENOTCONN 이 아님: \(type(of: error))")
    }
  }

  // MARK: - handshake 재접속

  @Test("handshake 거절은 재시도 횟수가 0이면 다시 연결하지 않고 원본 URL 오류를 던진다")
  func rejectedHandshakeWithoutRetry() async throws {
    let server = try LoopbackWebSocketServer([.reject(status: 401)])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest(maxRetryAttempts: 0))

    do {
      try await connection.send("never")
      Issue.record("거절된 handshake 의 송신은 실패해야 한다")
    } catch let error as URLError {
      #expect(error.code == .badServerResponse)
    } catch {
      Issue.record("원본 URL 오류가 아님: \(type(of: error))")
    }
    #expect(server.handshakes.count == 1)
    #expect(server.messages.isEmpty)
  }

  @Test("연결이 열리기 전 handshake 실패는 요청의 재시도 횟수 안에서 다시 연결한다")
  func handshakeRetryBeforeOpen() async throws {
    let server = try LoopbackWebSocketServer([
      .reject(status: 503),
      .accept([.echo, .waitForClientClose])
    ])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest(maxRetryAttempts: 1))

    try await connection.send("after-retry")
    let reply = try await connection.receive()
    connection.cancel()

    #expect(reply == "after-retry")
    #expect(server.handshakes.count == 2)
    #expect(server.messages == ["after-retry"])
  }

  @Test("열린 뒤 끊긴 연결은 다시 열지 않고 보낸 메시지도 다시 보내지 않는다")
  func noReconnectAfterOpen() async throws {
    let server = try LoopbackWebSocketServer([
      .accept([.receiveText]),
      .accept([.receiveText])
    ])
    defer { server.stop() }
    let connection = try makeClient(server).connect(SocketRequest(maxRetryAttempts: 3))

    try await connection.send("once")
    await #expect(throws: (any Error).self) {
      _ = try await connection.receive()
    }
    await #expect(throws: (any Error).self) {
      try await connection.send("again")
    }
    // 재시도가 있었다면 첫 지연(0.5초) 뒤 두 번째 handshake 가 들어온다.
    try await Task.sleep(for: .milliseconds(1_500))

    #expect(server.handshakes.count == 1)
    #expect(server.messages == ["once"])
  }

  @Test(
    "baseURL 이 없거나 http(s) 가 아니면 연결 전에 invalidURL 로 실패한다",
    arguments: [nil, URL(string: "ftp://127.0.0.1")] as [URL?]
  )
  func invalidBaseURL(baseURL: URL?) {
    let client = NetworkClient(
      session: SessionFactory.plain(),
      baseURL: baseURL
    )

    do {
      _ = try client.connect(SocketRequest())
      Issue.record("invalidURL 로 실패해야 한다")
    } catch {
      guard case .request(.invalidURL) = error else {
        Issue.record("invalidURL 이 아님: \(error)")
        return
      }
    }
  }

  // MARK: - 이벤트 기록

  @Test("실제 연결은 열림·송신·수신을 본문 없이 기록한다")
  func connectionRecordsEventsWithoutBodies() async throws {
    let server = try LoopbackWebSocketServer([.accept([.echo, .waitForClientClose])])
    defer { server.stop() }
    let events = RecordedWebSocketEvents()
    let session = SessionFactory.plain()
    let url = try #require(URL(string: server.baseURL.absoluteString.replacingOccurrences(
      of: "http://",
      with: "ws://"
    ) + "/socket/updates"))
    let request = session.webSocketRequest(performing: URLRequest(url: url))
    let id = FestiCoreEventMonitor.webSocketID(of: request)
    let connection = WebSocketConnection(
      request: request,
      session: session,
      record: { events.record($0) }
    )

    try await connection.send("private-request")
    _ = try await connection.receive()
    connection.cancel()

    #expect(events.values == [
      .opened(id: id),
      .sent(id: id),
      .received(id: id)
    ])
    #expect(!String(describing: events.values).contains("private-"))
  }

  @Test("handshake 로그는 경로만 남기고 인증 헤더·쿼리·오류 상세를 가린다")
  func handshakeSummaryRedactsSensitiveValues() throws {
    var request = URLRequest(url: try #require(URL(string: "wss://private-host.test/socket/updates?token=secret")))
    request.setValue(
      "Bearer private-access",
      forHTTPHeaderField: "Authorization"
    )
    let error = AFError.sessionTaskFailed(error: NSError(
      domain: "private-host/path?token=secret",
      code: 7,
      userInfo: [NSLocalizedDescriptionKey: "private-reason"]
    ))

    let summary = FestiCoreEventMonitor().webSocketSummary(
      id: "abcd1234",
      request: request,
      response: nil,
      duration: 0.25,
      error: error
    )

    #expect(summary.contains("WS #abcd1234 /socket/updates → -1 (250ms)"))
    #expect(summary.contains("domain=Other code=7"))
    for secret in ["private-host", "token=secret", "private-access", "private-reason"] {
      #expect(!summary.contains(secret))
    }
  }

  // MARK: - 연결 상태

  @Test("처음 온 종료 신호 하나만 반영하고 닫힘 이벤트는 한 번 남긴다")
  func firstTerminalSignalWins() async {
    let events = RecordedWebSocketEvents()
    let state = makeState(events)

    state.handle(.opened)
    state.handle(.disconnected(code: 1000))
    state.handle(.completed(.sessionTaskFailed(error: URLError(.networkConnectionLost))))
    state.handle(.cancelled)

    #expect(events.values == [
      .opened(id: "state"),
      .closed(
        id: "state",
        code: 1000
      )
    ])
    do {
      _ = try await state.nextMessage()
      Issue.record("끝난 연결의 수신은 실패해야 한다")
    } catch let error as POSIXError {
      #expect(error.code == .ENOTCONN)
    } catch {
      Issue.record("ENOTCONN 이 아님: \(type(of: error))")
    }
  }

  @Test("호출부 취소가 먼저 오면 늦은 전송 오류가 덮지 않는다")
  func cancelBeforeFailure() async {
    let events = RecordedWebSocketEvents()
    let state = makeState(events)

    state.handle(.cancelled)
    state.handle(.completed(.sessionTaskFailed(error: URLError(.networkConnectionLost))))

    #expect(events.values.isEmpty)
    await #expect(throws: CancellationError.self) {
      _ = try await state.nextMessage()
    }
  }

  @Test(
    "요청이 끝나면 AFError 를 벗겨 재접속 판단에 쓰는 원본 오류를 그대로 던진다",
    arguments: [
      NSError(
        domain: NSURLErrorDomain,
        code: URLError.networkConnectionLost.rawValue
      ),
      NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(POSIXErrorCode.ECONNRESET.rawValue)
      )
    ]
  )
  func completionKeepsOriginalError(original: NSError) async {
    let state = makeState(RecordedWebSocketEvents())

    state.handle(.completed(.sessionTaskFailed(error: original)))

    do {
      try await state.waitUntilOpen()
      Issue.record("끝난 연결은 열리지 않아야 한다")
    } catch {
      let thrown = error as NSError
      #expect(thrown.domain == original.domain)
      #expect(thrown.code == original.code)
    }
  }

  @Test("명시적 취소로 끝나면 CancellationError, 오류 없이 끝나면 ENOTCONN 이다")
  func completionWithoutTransportError() async {
    let cancelled = makeState(RecordedWebSocketEvents())
    cancelled.handle(.completed(.explicitlyCancelled))
    await #expect(throws: CancellationError.self) {
      _ = try await cancelled.nextMessage()
    }

    let finished = makeState(RecordedWebSocketEvents())
    finished.handle(.completed(nil))
    do {
      _ = try await finished.nextMessage()
      Issue.record("끝난 연결의 수신은 실패해야 한다")
    } catch let error as POSIXError {
      #expect(error.code == .ENOTCONN)
    } catch {
      Issue.record("ENOTCONN 이 아님: \(type(of: error))")
    }
  }

  @Test("종료 전에 받은 텍스트와 바이너리를 도착 순서대로 돌려준 뒤 종료 오류를 던진다")
  func bufferedMessagesBeforeEnd() async throws {
    let events = RecordedWebSocketEvents()
    let state = makeState(events)

    state.handle(.message(.string("private-text")))
    state.handle(.message(.data(Data([1]))))
    state.handle(.disconnected(code: 1001))

    #expect(try await state.nextMessage() == "private-text")
    await #expect(throws: FestiCoreWebSocketError.nonTextMessage) {
      _ = try await state.nextMessage()
    }
    await #expect(throws: POSIXError(.ENOTCONN)) {
      _ = try await state.nextMessage()
    }
    #expect(events.values == [
      .received(id: "state"),
      .nonText(id: "state"),
      .closed(
        id: "state",
        code: 1001
      )
    ])
    #expect(!String(describing: events.values).contains("private-"))
  }

  @Test("완료 콜백이 오지 않는 송신은 종료 신호가 원본 오류로 끝낸다")
  func endReleasesPendingSend() async {
    let state = makeState(RecordedWebSocketEvents())
    let started = AsyncStream<Void>.makeStream()
    let sending = Task {
      try await state.send { _ in
        // Alamofire 는 끝난 요청의 송신 완료를 부르지 않는다.
        started.continuation.yield()
      }
    }
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()

    state.handle(.completed(.sessionTaskFailed(error: URLError(.networkConnectionLost))))

    do {
      try await sending.value
      Issue.record("끝난 연결의 송신은 실패해야 한다")
    } catch let error as URLError {
      #expect(error.code == .networkConnectionLost)
    } catch {
      Issue.record("원본 URL 오류가 아님: \(type(of: error))")
    }
  }

  @Test("동시에 들어온 종료 신호도 연결당 닫힘 이벤트를 한 번까지만 남긴다")
  func concurrentTerminalSignals() async {
    let events = RecordedWebSocketEvents()
    let state = makeState(events)

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<40 {
        group.addTask {
          if index.isMultiple(of: 2) {
            state.handle(.disconnected(code: 1000))
          } else {
            state.handle(.completed(.sessionTaskFailed(error: URLError(.networkConnectionLost))))
          }
        }
      }
    }

    #expect(events.values.count <= 1)
  }
}

// MARK: - Helpers

private extension WebSocketTransportTests {
  func makeClient(_ server: LoopbackWebSocketServer) -> NetworkClient {
    return NetworkClient(
      session: SessionFactory.plain(),
      baseURL: server.baseURL
    )
  }

  func makeState(_ events: RecordedWebSocketEvents) -> WebSocketConnectionState {
    return WebSocketConnectionState(
      id: "state",
      record: { events.record($0) }
    )
  }

  /// 서버 스레드가 기록할 때까지 최대 5초 기다리고, 조건이 맞았는지 돌려준다.
  @discardableResult
  func waitUntil(_ condition: @Sendable () -> Bool) async throws -> Bool {
    for _ in 0..<50 where !condition() {
      try await Task.sleep(for: .milliseconds(100))
    }
    return condition()
  }
}

/// 테스트용 WebSocket 요청. 인증 없이 재시도 횟수만 바꾼다.
private struct SocketRequest: FestiCoreWebSocketRequest {
  var maxRetryAttempts = 0

  var path: String {
    return "socket/updates"
  }

  var headers: HTTPHeaders {
    return ["X-Socket-Test": "on"]
  }

  var authorization: FestiCoreAuthorization {
    return .none
  }
}

private final class RecordedWebSocketEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [FestiCoreEventMonitor.WebSocketEvent] = []

  var values: [FestiCoreEventMonitor.WebSocketEvent] {
    return lock.withLock { recorded }
  }

  func record(_ event: FestiCoreEventMonitor.WebSocketEvent) {
    lock.withLock { recorded.append(event) }
  }
}
