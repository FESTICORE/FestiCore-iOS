//
//  FestiCoreEventMonitor.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

import FestiCoreLogger

@_spi(WebSocket) import Alamofire

/// 요청 / 응답 / 에러를 한 덩어리로 묶어 로깅하는 `EventMonitor`.
/// 로깅은 `FestiCoreLogger(.network)` 에 위임 — 정상은 debug, 에러는 error 레벨.
/// WebSocket 도 같은 세션의 이 모니터가 handshake 시도·종료를 남긴다.
struct FestiCoreEventMonitor: EventMonitor {
  let queue = DispatchQueue(label: "io.festiCore.co.network.logger")

  /// 바디 로그 최대 길이 (초과 시 잘라냄)
  private let maxBodyLength = 4096

  // MARK: 요청 생성 실패 (URL / 파라미터 인코딩 등 — 전송 전)

  func request(_: Request, didFailToCreateURLRequestWithError error: AFError) {
    FestiCoreLogger.error("❌ [요청 생성 실패] \(error.localizedDescription)", category: .network)
  }

  // MARK: 요청 + 응답 (응답 시점에 한 덩어리로 묶어서 로깅)

  func request(
    _: DataRequest,
    didParseResponse response: DataResponse<some Sendable, AFError>
  ) {
    let urlRequest = response.request
    let method = urlRequest?.httpMethod ?? "?"
    let url = urlRequest?.url?.absoluteString ?? "?"
    let status = response.response?.statusCode ?? -1
    let milliseconds = Int((response.metrics?.taskInterval.duration ?? 0) * 1000)
    let isFailure = response.error != nil

    var lines = ["\(isFailure ? "❌" : "✅") \(method) \(url) → \(status) (\(milliseconds)ms)"]

    // ── 요청 ──
    if let headers = urlRequest?.allHTTPHeaderFields, !headers.isEmpty {
      lines.append("  · Request Headers\n\(format(NetworkLogRedactor.headers(headers)))")
    }
    if let body = urlRequest?.httpBody, !body.isEmpty {
      let description = NetworkLogRedactor.hidesBody(for: urlRequest?.url)
        ? "<redacted>" : prettyBody(body)
      lines.append("  · Request Body\n\(indent(description))")
    }

    // ── 응답 ──
    if let error = response.error {
      if case let .responseSerializationFailed(.decodingFailed(underlying)) = error,
         let decodingError = underlying as? DecodingError
      {
        lines.append(describe(decodingError))
      } else {
        lines.append("  · Error\n       \(error.localizedDescription)")
        if let underlying = error.underlyingError {
          lines.append("       underlying: \(underlying.localizedDescription)")
        }
      }
    }
    if let data = response.data, !data.isEmpty {
      let description = NetworkLogRedactor.hidesBody(for: urlRequest?.url)
        ? "<redacted>" : prettyBody(data)
      lines.append("  · Response Body\n\(indent(description))")
    }

    let message = lines.joined(separator: "\n")
    if isFailure {
      FestiCoreLogger.error(message, category: .network)
    } else {
      FestiCoreLogger.debug(message, category: .network)
    }
  }

  // MARK: WebSocket handshake (시도 · 종료)
  // Alamofire 에는 WebSocket 메시지 훅이 없어 열림·송수신·닫힘은 연결이 `log(_:)` 로 직접 남긴다.

  func request(
    _ request: Request,
    didCreateTask _: URLSessionTask
  ) {
    guard request is WebSocketRequest else { return }
    Self.log(.connecting(
      id: Self.webSocketID(of: request),
      attempt: request.retryCount + 1
    ))
  }

  func requestDidFinish(_ request: Request) {
    guard request is WebSocketRequest else { return }
    let message = webSocketSummary(
      id: Self.webSocketID(of: request),
      request: request.request,
      response: request.response,
      duration: request.metrics?.taskInterval.duration ?? 0,
      error: request.error
    )
    if request.error == nil {
      FestiCoreLogger.debug(
        message,
        category: .network
      )
    } else {
      FestiCoreLogger.error(
        message,
        category: .network
      )
    }
  }
}

// MARK: - WebSocket

extension FestiCoreEventMonitor {
  /// WebSocket 이벤트. 주소·헤더·본문·종료 사유는 넣지 않는다.
  enum WebSocketEvent: Equatable, Sendable {
    case connecting(id: String, attempt: Int)
    case opened(id: String)
    case sent(id: String)
    case received(id: String)
    case nonText(id: String)
    case closed(id: String, code: Int)
  }

  /// 로그에서 연결을 구분하는 짧은 번호. 요청 UUID 의 앞 8자리다.
  static func webSocketID(of request: Request) -> String {
    return String(request.id.uuidString.prefix(8))
  }

  static func log(_ event: WebSocketEvent) {
    let message = description(of: event)
    switch event {
    case .nonText, .closed:
      FestiCoreLogger.notice(
        message,
        category: .network
      )
    case .connecting, .opened, .sent, .received:
      FestiCoreLogger.debug(
        message,
        category: .network
      )
    }
  }

  static func description(of event: WebSocketEvent) -> String {
    switch event {
    case let .connecting(
      id,
      attempt
    ):
      return "🔌 WS #\(id) connecting (attempt \(attempt))"
    case let .opened(id):
      return "🔌 WS #\(id) connected"
    case let .sent(id):
      return "🔌 WS #\(id) text sent"
    case let .received(id):
      return "🔌 WS #\(id) text received"
    case let .nonText(id):
      return "🔌 WS #\(id) non-text message rejected"
    case let .closed(
      id,
      code
    ):
      return "🔌 WS #\(id) closed code=\(code)"
    }
  }

  /// WebSocket handshake 결과 한 덩어리. 주소는 경로만 남기고, 헤더는 `NetworkLogRedactor` 로 가리고,
  /// 오류는 도메인·코드만 남긴다.
  func webSocketSummary(
    id: String,
    request: URLRequest?,
    response: HTTPURLResponse?,
    duration: TimeInterval,
    error: AFError?
  ) -> String {
    let path = request?.url?.path ?? "?"
    let status = response?.statusCode ?? -1
    let milliseconds = Int(duration * 1000)
    var lines = ["\(error == nil ? "✅" : "❌") WS #\(id) \(path) → \(status) (\(milliseconds)ms)"]
    if let headers = request?.allHTTPHeaderFields, !headers.isEmpty {
      lines.append("  · Request Headers\n\(format(NetworkLogRedactor.headers(headers)))")
    }
    if let error {
      lines.append("  · Error\n       \(NetworkLogRedactor.errorSummary(error.underlyingError ?? error))")
    }
    return lines.joined(separator: "\n")
  }
}

private extension FestiCoreEventMonitor {
  /// `DecodingError` 를 "종류 · 위치 · 상세" 세 줄로 정리한다.
  /// 원시 Response Body 와 분리해 무엇이 왜 틀렸는지만 짚는다.
  func describe(_ error: DecodingError) -> String {
    func location(_ context: DecodingError.Context, key: String? = nil) -> String {
      var parts = context.codingPath.map(\.stringValue)
      if let key { parts.append(key) }
      return parts.isEmpty ? "(root)" : parts.joined(separator: ".")
    }

    let kind: String
    let place: String
    let detail: String
    switch error {
    case let .keyNotFound(key, context):
      kind = "keyNotFound"
      place = location(context, key: key.stringValue)
      detail = "'\(key.stringValue)' 키가 응답에 없음"
    case let .typeMismatch(type, context):
      kind = "typeMismatch"
      place = location(context)
      detail = "기대 타입 \(type)"
    case let .valueNotFound(type, context):
      kind = "valueNotFound"
      place = location(context)
      detail = "\(type) 필수인데 null"
    case let .dataCorrupted(context):
      kind = "dataCorrupted"
      place = location(context)
      detail = context.debugDescription
    @unknown default:
      kind = "unknown"
      place = "-"
      detail = String(describing: error)
    }

    return [
      "  · Decoding Error",
      "       종류: \(kind)",
      "       위치: \(place)",
      "       상세: \(detail)"
    ].joined(separator: "\n")
  }

  /// 헤더를 정렬해 한 줄씩 들여쓰기.
  func format(_ headers: [String: String]) -> String {
    headers
      .sorted { $0.key < $1.key }
      .map { "       \($0.key): \($0.value)" }
      .joined(separator: "\n")
  }

  /// 여러 줄 텍스트를 들여쓰기 (바디 블록 정렬용).
  func indent(_ text: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { "       \($0)" }
      .joined(separator: "\n")
  }

  /// JSON 이면 pretty-print, 아니면 UTF-8 문자열. 길면 잘라낸다.
  func prettyBody(_ data: Data) -> String {
    let text: String = if let object = try? JSONSerialization.jsonObject(with: data),
                          let pretty = try? JSONSerialization.data(
                            withJSONObject: object,
                            options: [.prettyPrinted, .withoutEscapingSlashes]
                          ),
                          let string = String(data: pretty, encoding: .utf8)
    {
      string
    } else {
      String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }
    guard text.count > maxBodyLength else { return text }
    return text.prefix(maxBodyLength) + "… (truncated)"
  }
}
