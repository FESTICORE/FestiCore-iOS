//
//  FestivalPackSocketRequest.swift
//  APIEndpoint
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import API
import FestiCoreNetworkInterface

public enum FestivalPackSocketRequest: FestiCoreWebSocketRequest, Sendable {
  /// 팩 요청(`pack.get`)과 변경 알림(`pack.updated`)을 주고받는 연결. 공개 채널이라 인증하지 않는다.
  case updates

  public var path: String {
    switch self {
    case .updates: return FestivalAPI.packUpdates.path
    }
  }

  public var authorization: FestiCoreAuthorization {
    return .none
  }

  /// handshake 재접속을 하지 않는다. 팩 서비스가 끊긴 연결을 ETag 와 함께 다시 열고 `pack.get` 을 다시 보낸다.
  public var maxRetryAttempts: Int {
    return 0
  }
}
