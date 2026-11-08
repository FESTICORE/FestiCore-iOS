//
//  LoopbackWebSocketServer.swift
//  FestiCoreNetworkTests
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import CryptoKit
import Darwin
import Foundation

/// 테스트용 로컬 WebSocket 서버. 외부 네트워크 없이 연결마다 정해 둔 handshake 와 동작을 차례로 수행한다.
/// 각본이 끝난 뒤 들어오는 handshake 는 503 으로 거절하고 횟수만 센다.
final class LoopbackWebSocketServer: @unchecked Sendable {
  enum Handshake: Sendable {
    /// upgrade 대신 이 status 로 거절한다.
    case reject(status: Int)
    /// upgrade 한 뒤 동작을 차례로 수행하고 TCP 연결을 끊는다.
    case accept([Step])
  }

  enum Step: Sendable {
    /// 텍스트 메시지를 보낸다.
    case sendText(String)
    /// 바이너리 메시지를 보낸다.
    case sendBinary([UInt8])
    /// 클라이언트 텍스트 메시지 하나를 받아 기록한다.
    case receiveText
    /// 클라이언트 텍스트 메시지 하나를 받아 기록하고 그대로 돌려준다.
    case echo
    /// close frame 을 보내고 클라이언트 응답을 기다린다.
    case close(code: UInt16, reason: String)
    /// 클라이언트가 close frame 을 보내거나 연결을 끊을 때까지 받은 메시지를 기록한다.
    case waitForClientClose
  }

  /// `http://127.0.0.1:<port>` — 클라이언트가 ws 로 바꿔 연결한다.
  let baseURL: URL

  private let listener: Int32
  private let lock = NSLock()
  private var script: [Handshake]
  private var stopped = false
  private var recordedHandshakes: [String] = []
  private var recordedMessages: [String] = []
  private var recordedCloseCodes: [UInt16] = []

  /// 받은 handshake 요청 원문(요청 줄과 헤더)
  var handshakes: [String] {
    return lock.withLock { recordedHandshakes }
  }

  /// 클라이언트가 보낸 텍스트 메시지
  var messages: [String] {
    return lock.withLock { recordedMessages }
  }

  /// 클라이언트가 보낸 close frame 의 코드
  var clientCloseCodes: [UInt16] {
    return lock.withLock { recordedCloseCodes }
  }

  init(_ script: [Handshake]) throws {
    let listener = Darwin.socket(
      AF_INET,
      SOCK_STREAM,
      0
    )
    guard listener >= 0 else { throw POSIXError(.EIO) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: in_addr_t(0x7f00_0001).bigEndian)
    let bound = withUnsafePointer(to: &address) { pointer in
      return pointer.withMemoryRebound(
        to: sockaddr.self,
        capacity: 1
      ) {
        return Darwin.bind(
          listener,
          $0,
          socklen_t(MemoryLayout<sockaddr_in>.size)
        )
      }
    }
    guard bound == 0, Darwin.listen(
      listener,
      8
    ) == 0 else {
      Darwin.close(listener)
      throw POSIXError(.EADDRINUSE)
    }

    var localAddress = sockaddr_in()
    var localLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let named = withUnsafeMutablePointer(to: &localAddress) { pointer in
      return pointer.withMemoryRebound(
        to: sockaddr.self,
        capacity: 1
      ) {
        return Darwin.getsockname(
          listener,
          $0,
          &localLength
        )
      }
    }
    guard named == 0 else {
      Darwin.close(listener)
      throw POSIXError(.EIO)
    }

    self.listener = listener
    self.script = script
    baseURL = URL(string: "http://127.0.0.1:\(UInt16(bigEndian: localAddress.sin_port))")!
    Thread.detachNewThread { [self] in serve() }
  }

  /// 새 연결을 더 받지 않고 서버를 닫는다.
  func stop() {
    lock.withLock { stopped = true }
  }
}

private extension LoopbackWebSocketServer {
  /// RFC 6455 handshake 에 쓰는 고정 GUID
  static let handshakeGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  var isStopped: Bool {
    return lock.withLock { stopped }
  }

  func serve() {
    defer { Darwin.close(listener) }
    while !isStopped {
      guard let descriptor = acceptClient() else { continue }
      let connection = LoopbackConnection(descriptor: descriptor)
      handle(connection)
      connection.close()
    }
  }

  func acceptClient() -> Int32? {
    var waiting = pollfd(
      fd: listener,
      events: Int16(POLLIN),
      revents: 0
    )
    guard Darwin.poll(
      &waiting,
      1,
      100
    ) > 0 else { return nil }
    let descriptor = Darwin.accept(
      listener,
      nil,
      nil
    )
    return descriptor >= 0 ? descriptor : nil
  }

  func handle(_ connection: LoopbackConnection) {
    guard let request = connection.readHandshake() else { return }
    let handshake: Handshake = lock.withLock {
      recordedHandshakes.append(request)
      return script.isEmpty ? .reject(status: 503) : script.removeFirst()
    }
    switch handshake {
    case let .reject(status):
      connection.write(Array("HTTP/1.1 \(status) Rejected\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
    case let .accept(steps):
      guard let key = Self.webSocketKey(in: request) else { return }
      connection.write(Array(
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(Self.acceptValue(for: key))\r\n\r\n".utf8
      ))
      for step in steps {
        guard perform(
          step,
          on: connection
        ) else { return }
      }
    }
  }

  /// 동작 하나를 수행한다. 연결이 끝나 다음 동작을 할 수 없으면 false 다.
  func perform(
    _ step: Step,
    on connection: LoopbackConnection
  ) -> Bool {
    switch step {
    case let .sendText(text):
      connection.writeFrame(
        opcode: LoopbackConnection.textOpcode,
        payload: Array(text.utf8)
      )
      return true
    case let .sendBinary(bytes):
      connection.writeFrame(
        opcode: LoopbackConnection.binaryOpcode,
        payload: bytes
      )
      return true
    case .receiveText:
      guard let text = connection.readText() else { return false }
      lock.withLock { recordedMessages.append(text) }
      return true
    case .echo:
      guard let text = connection.readText() else { return false }
      lock.withLock { recordedMessages.append(text) }
      connection.writeFrame(
        opcode: LoopbackConnection.textOpcode,
        payload: Array(text.utf8)
      )
      return true
    case let .close(
      code,
      reason
    ):
      connection.writeFrame(
        opcode: LoopbackConnection.closeOpcode,
        payload: [UInt8(code >> 8), UInt8(code & 0xFF)] + Array(reason.utf8)
      )
      _ = connection.readFrame()
      return false
    case .waitForClientClose:
      while let frame = connection.readFrame() {
        if frame.opcode == LoopbackConnection.closeOpcode {
          let code = frame.payload.count >= 2 ? UInt16(frame.payload[0]) << 8 | UInt16(frame.payload[1]) : 0
          lock.withLock { recordedCloseCodes.append(code) }
          return false
        }
        if frame.opcode == LoopbackConnection.textOpcode {
          let text = LoopbackConnection.text(from: frame.payload)
          lock.withLock { recordedMessages.append(text) }
        }
      }
      return false
    }
  }

  static func webSocketKey(in request: String) -> String? {
    let prefix = "sec-websocket-key:"
    let line = request
      .components(separatedBy: "\r\n")
      .first { $0.lowercased().hasPrefix(prefix) }
    return line.map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
  }

  static func acceptValue(for key: String) -> String {
    let digest = Insecure.SHA1.hash(data: Data((key + handshakeGUID).utf8))
    return Data(digest).base64EncodedString()
  }
}

/// 서버 쪽 TCP 연결 하나. 읽기는 5초 안에 끝나지 않으면 끝난 연결로 본다.
private final class LoopbackConnection {
  struct Frame {
    let opcode: UInt8
    let payload: [UInt8]
  }

  static let textOpcode: UInt8 = 0x1
  static let binaryOpcode: UInt8 = 0x2
  static let closeOpcode: UInt8 = 0x8

  static func text(from bytes: [UInt8]) -> String {
    return String(
      decoding: bytes,
      as: UTF8.self
    )
  }

  private let descriptor: Int32
  private var buffer: [UInt8] = []

  init(descriptor: Int32) {
    self.descriptor = descriptor
    // 클라이언트가 먼저 끊은 소켓에 써도 테스트 프로세스가 SIGPIPE 로 끝나지 않게 한다.
    var enabled: Int32 = 1
    _ = Darwin.setsockopt(
      descriptor,
      SOL_SOCKET,
      SO_NOSIGPIPE,
      &enabled,
      socklen_t(MemoryLayout<Int32>.size)
    )
  }

  func readHandshake() -> String? {
    let terminator: [UInt8] = Array("\r\n\r\n".utf8)
    while true {
      if let end = endIndex(of: terminator) {
        let header = Array(buffer[..<end])
        buffer.removeFirst(end)
        return Self.text(from: header)
      }
      guard buffer.count < 16_384, fill() else { return nil }
    }
  }

  /// 다음 텍스트 메시지를 읽는다. ping·pong 은 건너뛰고, 닫히면 nil 이다.
  func readText() -> String? {
    while let frame = readFrame() {
      if frame.opcode == Self.textOpcode {
        return Self.text(from: frame.payload)
      }
      if frame.opcode == Self.closeOpcode {
        return nil
      }
    }
    return nil
  }

  func readFrame() -> Frame? {
    guard let header = read(2) else { return nil }
    var length = Int(header[1] & 0x7F)
    if length == 126 {
      guard let extended = read(2) else { return nil }
      length = Int(extended[0]) << 8 | Int(extended[1])
    } else if length == 127 {
      guard let extended = read(8) else { return nil }
      length = extended.reduce(0) { $0 << 8 | Int($1) }
    }
    let mask = header[1] & 0x80 == 0 ? nil : read(4)
    guard var payload = read(length) else { return nil }
    if let mask {
      for index in payload.indices {
        payload[index] ^= mask[index % 4]
      }
    }
    return Frame(
      opcode: header[0] & 0x0F,
      payload: payload
    )
  }

  /// 서버 frame 은 마스크하지 않는다.
  func writeFrame(
    opcode: UInt8,
    payload: [UInt8]
  ) {
    var frame: [UInt8] = [0x80 | opcode]
    if payload.count < 126 {
      frame.append(UInt8(payload.count))
    } else {
      frame += [126, UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)]
    }
    write(frame + payload)
  }

  func write(_ bytes: [UInt8]) {
    var sent = 0
    while sent < bytes.count {
      let count = bytes[sent...].withUnsafeBytes { buffer in
        return Darwin.write(
          descriptor,
          buffer.baseAddress,
          buffer.count
        )
      }
      guard count > 0 else { return }
      sent += count
    }
  }

  func close() {
    Darwin.close(descriptor)
  }

  private func read(_ count: Int) -> [UInt8]? {
    while buffer.count < count {
      guard fill() else { return nil }
    }
    let bytes = Array(buffer.prefix(count))
    buffer.removeFirst(count)
    return bytes
  }

  private func fill() -> Bool {
    var waiting = pollfd(
      fd: descriptor,
      events: Int16(POLLIN),
      revents: 0
    )
    guard Darwin.poll(
      &waiting,
      1,
      5_000
    ) > 0 else { return false }
    var chunk = [UInt8](repeating: 0, count: 4_096)
    let count = Darwin.read(
      descriptor,
      &chunk,
      chunk.count
    )
    guard count > 0 else { return false }
    buffer.append(contentsOf: chunk.prefix(count))
    return true
  }

  private func endIndex(of terminator: [UInt8]) -> Int? {
    guard buffer.count >= terminator.count else { return nil }
    for start in 0...(buffer.count - terminator.count) where Array(buffer[start..<(start + terminator.count)]) == terminator {
      return start + terminator.count
    }
    return nil
  }
}
