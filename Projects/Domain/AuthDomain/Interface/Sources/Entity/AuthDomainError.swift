//
//  AuthDomainError.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public enum AuthDomainError: Error, Sendable, Equatable {
  case invalidCredential
  case invalidResponse
  case notAuthenticated
  /// 인증 요청이 연결 실패 또는 타임아웃으로 완료되지 않았다.
  case offline
  /// 서버가 최신 약관 동의가 필요하다고 응답했다.
  case termsOutdated
  case configurationMissing
  case missingPresentingController
  case missingIDToken
  case missingAuthorizationCode
  case userCancelled
  case requestInProgress
  case providerFailure
  case localSessionClearFailed
  case revocationOutcomeUnknown
  /// 닉네임이 1~12자가 아니다.
  case invalidNickname
}
