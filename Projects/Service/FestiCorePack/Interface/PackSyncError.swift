//
//  PackSyncError.swift
//  FestiCorePackInterface
//
//  Created by FestiCore on 11/3/26.
//

import Darwin
import Foundation

/// 팩 동기화 실패 이유. Domain이 오프라인·시간 초과를 구분할 수 있게 Interface에 둔다.
public enum PackSyncError: Error, Sendable, Equatable {
  case unconfigured
  case invalidFestivalID
  case invalidEndpoint
  case invalidMessage
  case invalidPack
  case invalidChunk
  case timeout
  case packTooLarge
  /// 응답을 기다리는 동안 사용자가 팩을 지웠다.
  case packDeleted
  case server(String)
}

public extension PackSyncError {
  /// 연결·전송 실패나 응답 시간 초과인지. 재접속 판단과 Domain의 오프라인 안내가 함께 쓴다.
  static func isTransportFailure(_ error: any Error) -> Bool {
    if let syncError = error as? PackSyncError { return syncError == .timeout }
    if let urlError = error as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
           .cannotFindHost, .timedOut, .dnsLookupFailed, .internationalRoamingOff,
           .dataNotAllowed, .callIsActive, .badServerResponse:
        return true
      default:
        return false
      }
    }
    let nsError = error as NSError
    guard nsError.domain == NSPOSIXErrorDomain else { return false }
    return [ENETDOWN, ENETUNREACH, ECONNRESET, ECONNABORTED, ENOTCONN,
            ECONNREFUSED, ETIMEDOUT, EHOSTUNREACH, EPIPE]
      .contains(Int32(nsError.code))
  }
}
