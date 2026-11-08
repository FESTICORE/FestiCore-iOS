//
//  WebSocketConnection.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

import FestiCoreNetworkInterface

@_spi(WebSocket) import Alamofire

/// Alamofire `WebSocketRequest` 위의 텍스트 연결.
///
/// 메시지는 연결이 열린 뒤 한 번만 보낸다. handshake 재접속은 요청의 재시도 정책이 맡고,
/// 열린 뒤 끊긴 연결이나 실패한 메시지는 다시 보내지 않는다.
final class WebSocketConnection: FestiCoreWebSocketConnection {
  /// 조립된 Alamofire WebSocket 요청
  private let request: WebSocketRequest
  /// Alamofire 이벤트를 송수신 대기와 잇는 상태
  private let state: WebSocketConnectionState
  /// 이벤트와 송신 완료를 순서대로 받는 큐
  private let queue = DispatchQueue(label: "io.festiCore.co.network.websocket")

  init(
    request: WebSocketRequest,
    session: Session,
    record: @escaping @Sendable (FestiCoreEventMonitor.WebSocketEvent) -> Void = FestiCoreEventMonitor.log
  ) {
    let state = WebSocketConnectionState(
      id: FestiCoreEventMonitor.webSocketID(of: request),
      record: record
    )
    self.request = request
    self.state = state
    // 핸들러는 연결이 열리기 전에 달아야 첫 메시지를 놓치지 않는다. 핸들러를 달면 요청이 시작된다.
    // 요청은 세션을 약하게 참조하므로 핸들러가 요청이 끝날 때까지 세션을 붙잡는다.
    // 연결을 먼저 놓아도 세션이 남은 닫힘·완료 콜백을 받아야 Alamofire 가 요청을 정리한다.
    request.streamMessageEvents(on: queue) { event in
      withExtendedLifetime(session) {
        state.handle(Self.signal(for: event.kind))
      }
    }
  }

  deinit {
    // 닫지 않고 놓은 연결도 닫아, 세션을 붙잡은 요청이 열린 채 남지 않게 한다.
    request.close(sending: .goingAway)
  }

  func send(_ text: String) async throws {
    try await state.waitUntilOpen()
    try await state.send { [request, queue] completion in
      request.send(
        .string(text),
        queue: queue,
        completionHandler: completion
      )
    }
  }

  func receive() async throws -> String {
    return try await state.nextMessage()
  }

  func cancel() {
    state.handle(.cancelled)
    request.close(sending: .goingAway)
  }
}

private extension WebSocketConnection {
  /// Alamofire 이벤트를 연결 상태 신호로 옮긴다.
  static func signal(
    for kind: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Never>.Kind
  ) -> WebSocketConnectionState.Signal {
    switch kind {
    case .connected:
      return .opened
    case let .receivedMessage(message):
      return .message(message)
    case let .disconnected(
      closeCode,
      _
    ):
      return .disconnected(code: closeCode.rawValue)
    case let .completed(completion):
      return .completed(completion.error)
    }
  }
}

/// WebSocket 이벤트로 송수신 대기를 깨우는 연결 상태. Alamofire 콜백과 async 호출부를 잇는다.
///
/// 처음 도착한 종료 신호 하나만 반영하고, 종료 전에 받은 메시지는 먼저 돌려준다.
final class WebSocketConnectionState: @unchecked Sendable {
  enum Signal {
    /// handshake 가 끝나 연결이 열렸다.
    case opened
    /// 서버가 보낸 메시지
    case message(URLSessionWebSocketTask.Message)
    /// 서버나 네트워크가 연결을 닫았다.
    case disconnected(code: Int)
    /// 요청이 끝났다. handshake 재접속까지 실패했으면 오류를 담는다.
    case completed(AFError?)
    /// 호출부가 연결을 닫았다.
    case cancelled
  }

  private enum Phase {
    case connecting
    case open
    case ended(any Error)
  }

  /// 로그에서 연결을 구분하는 짧은 번호
  private let id: String
  /// 본문 없이 이벤트를 남기는 기록기
  private let record: @Sendable (FestiCoreEventMonitor.WebSocketEvent) -> Void
  private let lock = NSLock()
  private var phase = Phase.connecting
  private var messages: [Result<String, any Error>] = []
  private var receivers: [CheckedContinuation<String, any Error>] = []
  private var openWaiters: [CheckedContinuation<Void, any Error>] = []
  private var sends: [UUID: CheckedContinuation<Void, any Error>] = [:]

  init(
    id: String,
    record: @escaping @Sendable (FestiCoreEventMonitor.WebSocketEvent) -> Void
  ) {
    self.id = id
    self.record = record
  }

  func handle(_ signal: Signal) {
    switch signal {
    case .opened:
      open()
    case let .message(message):
      deliver(message)
    case let .disconnected(code):
      // 닫힌 소켓의 수신은 URLSession 처럼 ENOTCONN 으로 끝낸다. 호출부는 이 오류로 재접속한다.
      end(
        with: POSIXError(.ENOTCONN),
        closeCode: code
      )
    case let .completed(error):
      end(with: error.map(Self.originalError) ?? POSIXError(.ENOTCONN))
    case .cancelled:
      end(with: CancellationError())
    }
  }

  /// 연결이 열릴 때까지 기다린다. 열리기 전에 끝나면 그 오류를 던진다.
  func waitUntilOpen() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      let outcome: Result<Void, any Error>? = lock.withLock {
        switch phase {
        case .connecting:
          openWaiters.append(continuation)
          return nil
        case .open:
          return .success(())
        case let .ended(error):
          return .failure(error)
        }
      }
      if let outcome {
        continuation.resume(with: outcome)
      }
    }
  }

  /// 다음 메시지를 돌려준다. 받은 메시지가 없고 연결이 끝났으면 종료 오류를 던진다.
  func nextMessage() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      let outcome: Result<String, any Error>? = lock.withLock {
        if !messages.isEmpty {
          return messages.removeFirst()
        }
        if case let .ended(error) = phase {
          return .failure(error)
        }
        receivers.append(continuation)
        return nil
      }
      if let outcome {
        continuation.resume(with: outcome)
      }
    }
  }

  /// 메시지 하나를 보낸다. 송신 완료와 연결 종료 중 먼저 오는 쪽으로 끝낸다.
  /// Alamofire 는 이미 끝난 요청의 송신 완료를 부르지 않으므로 종료 신호가 대기를 풀어 준다.
  func send(_ perform: (@escaping @Sendable (Result<Void, any Error>) -> Void) -> Void) async throws {
    let sendID = UUID()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      let endedError: (any Error)? = lock.withLock {
        if case let .ended(error) = phase {
          return error
        }
        sends[sendID] = continuation
        return nil
      }
      if let endedError {
        continuation.resume(throwing: endedError)
        return
      }
      perform { [self] result in
        finishSend(
          sendID,
          with: result
        )
      }
    }
    record(.sent(id: id))
  }
}

private extension WebSocketConnectionState {
  func open() {
    let waiters: [CheckedContinuation<Void, any Error>]? = lock.withLock {
      guard case .connecting = phase else { return nil }
      phase = .open
      defer { openWaiters = [] }
      return openWaiters
    }
    guard let waiters else { return }
    record(.opened(id: id))
    waiters.forEach { $0.resume() }
  }

  func deliver(_ message: URLSessionWebSocketTask.Message) {
    let result: Result<String, any Error>
    if case let .string(text) = message {
      result = .success(text)
      record(.received(id: id))
    } else {
      result = .failure(FestiCoreWebSocketError.nonTextMessage)
      record(.nonText(id: id))
    }
    let receiver: CheckedContinuation<String, any Error>? = lock.withLock {
      guard !receivers.isEmpty else {
        messages.append(result)
        return nil
      }
      return receivers.removeFirst()
    }
    receiver?.resume(with: result)
  }

  func end(
    with error: any Error,
    closeCode: Int? = nil
  ) {
    let waiting: Waiting? = lock.withLock {
      if case .ended = phase { return nil }
      phase = .ended(error)
      defer {
        receivers = []
        openWaiters = []
        sends = [:]
      }
      return Waiting(
        receivers: receivers,
        openWaiters: openWaiters,
        sends: Array(sends.values)
      )
    }
    guard let waiting else { return }
    if let closeCode {
      record(.closed(
        id: id,
        code: closeCode
      ))
    }
    waiting.receivers.forEach { $0.resume(throwing: error) }
    waiting.openWaiters.forEach { $0.resume(throwing: error) }
    waiting.sends.forEach { $0.resume(throwing: error) }
  }

  func finishSend(
    _ sendID: UUID,
    with result: Result<Void, any Error>
  ) {
    let continuation = lock.withLock { sends.removeValue(forKey: sendID) }
    continuation?.resume(with: result)
  }

  /// AFError 를 벗겨 URLSession 의 원본 오류를 돌려준다. 호출부는 URL·POSIX 오류로 재접속을 판단한다.
  static func originalError(_ error: AFError) -> any Error {
    if case .explicitlyCancelled = error {
      return CancellationError()
    }
    return error.underlyingError ?? error
  }

  /// 연결이 끝날 때 함께 깨울 대기열
  struct Waiting {
    let receivers: [CheckedContinuation<String, any Error>]
    let openWaiters: [CheckedContinuation<Void, any Error>]
    let sends: [CheckedContinuation<Void, any Error>]
  }
}
