//
//  BearerError.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public enum BearerError: Error, Sendable, Equatable {
  /// 로그인 세션이 없거나 만료됐다.
  case notAuthenticated
  /// 현재 약관 동의가 필요하다(403 `TERMS_REQUIRED`).
  case termsRequired
  /// 이 깃발의 기수가 아니다.
  case notBearer
  /// 원래 기수만 할 수 있다.
  case notOwner
  case notFound
  case zoneNotFound
  /// 같은 축제에 같은 이름의 깃발이 있다.
  case nameTaken
  /// 다른 기기·공동 기수가 더 최근에 바꿨다(409 `STATUS_STALE`).
  case stale
  /// 지금 상태에서 허용되지 않는 전이·재시작이다.
  case transitionRejected
  /// 사진이 동시에 바뀌었거나 멱등키가 충돌했다.
  case conflict
  case coBearerFull
  /// 축제당 한 깃발만 맡을 수 있다.
  case bearerLimit
  /// 원래 기수는 해제할 수 없다.
  case ownerRequired
  /// 코드가 맞지 않다. 서버가 남은 횟수를 주면 함께 담는다.
  case invalidCode(remainingAttempts: Int?)
  /// 코드 입력이 잠겼다.
  case codeLocked(retryAfter: Int)
  /// 상태 변경 분당 한도 초과
  case rateLimited
  case photoTooSmall
  case photoTooLarge
  case unsupportedPhoto
  case invalidRequest
  /// 네트워크에 연결하지 못했다. 상태 변경은 대기열에 넣는다.
  case offline
  case unavailable
  case invalidResponse
}
