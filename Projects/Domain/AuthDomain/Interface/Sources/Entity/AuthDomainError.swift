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
  /// 네트워크에 연결할 수 없거나 응답 시간이 지났다.
  case offline
  /// 서버의 현재 약관 버전과 동의한 버전이 다르다.
  case termsVersionOutdated
  /// 서버나 요청 오류로 계정 요청을 마치지 못했다.
  case unavailable
}
