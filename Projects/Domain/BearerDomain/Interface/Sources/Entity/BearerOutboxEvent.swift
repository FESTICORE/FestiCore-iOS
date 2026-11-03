//
//  BearerOutboxEvent.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 상태 변경 대기열(아웃박스)이 기수 보드에 알리는 일
public enum BearerOutboxEvent: Sendable, Equatable {
  /// 이 깃발의 보내지 못한 변경 목록이 바뀌었다.
  case pending([BearerStatusRequest])
  /// 한 건을 서버가 받았다.
  case sent(id: String, BearerFlagStatus)
  /// 연결이 없어 잠시 뒤 다시 보낸다.
  case offline
  /// 로그인이 풀려 멈췄다. 대기열은 남아 있고 다시 로그인한 뒤 이어서 보낸다.
  case needsLogin
  /// 서버 오류가 계속돼 자동 재시도를 멈췄다. 대기열은 남아 있다.
  case gaveUp(BearerError)
  /// 서버가 받지 않는 변경이라 이 깃발의 대기열을 비웠다. 최신 상태를 다시 읽어야 한다.
  case rejected(BearerError)
}
