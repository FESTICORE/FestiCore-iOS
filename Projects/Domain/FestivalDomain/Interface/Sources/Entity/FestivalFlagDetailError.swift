//
//  FestivalFlagDetailError.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

/// 깃발 상세 조회 실패.
public enum FestivalFlagDetailError: Error, Equatable, Sendable {
  /// 없거나 비공개·숨김 처리된 깃발.
  case notFound
  /// 연결 실패나 서버 오류. 다시 시도할 수 있다.
  case unavailable
  /// 응답 형식이 계약과 다르다.
  case invalidResponse
}
