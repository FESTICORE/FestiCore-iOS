//
//  FestivalFlagPinError.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/8/26.
//

/// 잠금화면에 표시할 대표 깃발 지정 실패.
public enum FestivalFlagPinError: Error, Equatable, Sendable {
  /// 로그아웃 상태이거나 토큰 갱신 후에도 인증되지 않았다.
  case loginRequired
  /// 지정 전에 최신 약관에 다시 동의해야 한다.
  case termsRequired
  /// 팔로우하지 않은 깃발은 지정할 수 없다.
  case notFollowing
  /// 요청 URL이나 본문을 만들 수 없어 서버에 전송하지 못했다.
  case invalidRequest
  /// 응답 형식이 계약과 다르다.
  case invalidResponse
  /// 연결 오류·5xx처럼 결과를 알 수 없다.
  case unavailable
}
