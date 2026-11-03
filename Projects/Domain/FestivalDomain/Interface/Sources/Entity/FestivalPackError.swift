//
//  FestivalPackError.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

public enum FestivalPackError: Error, Equatable, Sendable {
  /// 테스트·프리뷰에서 주입하지 않은 호출
  case notRegistered
  /// 서버 응답 형식이 계약과 다르다.
  case invalidResponse
  /// 서버가 잠시 뒤 다시 받으라고 했다.
  case retryLater
  /// 네트워크에 연결되지 않았거나 응답이 오지 않는다.
  case offline
}
