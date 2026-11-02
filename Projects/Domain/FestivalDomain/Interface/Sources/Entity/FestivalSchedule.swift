//
//  FestivalSchedule.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Foundation

/// 서버에 저장된 내 일정. 공개 팩의 공연 ID 목록이다.
public struct FestivalSchedule: Equatable, Sendable {
  public let setIDs: [String]

  public init(setIDs: [String]) {
    self.setIDs = setIDs
  }
}

public enum FestivalScheduleError: Error, Equatable, Sendable {
  /// 토큰 갱신 후에도 인증되지 않았다. 로그인 전 사용자다.
  case unauthorized
  /// 더 최신 일정이 서버에 있다. 서버 값을 함께 돌려준다.
  case stale(FestivalSchedule)
  /// 서버가 요청을 거부했다(없는 공연 ID 등).
  case rejected
  /// 연결 오류·5xx처럼 결과를 알 수 없다.
  case unavailable
}
