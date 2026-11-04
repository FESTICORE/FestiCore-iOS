//
//  SignUpDelegate.swift
//  AuthInterface
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import Foundation

@CasePathable
public enum SignUpDelegate: Equatable, Sendable {
  case submitRequested(SignUpSubmission)
  case closeRequested
  case legalDocumentRequested(url: URL, title: String)
}

/// 가입 시트에서 제출한 값. 닉네임은 앞뒤 공백을 지운 값이다.
public struct SignUpSubmission: Equatable, Sendable {
  public let nickname: String
  public let pushOptIn: Bool
  /// 닉네임이 1~12자 규칙을 지키는지. 규칙은 `SignUpFeature`가 판단한다.
  public let isNicknameValid: Bool

  public init(nickname: String, pushOptIn: Bool, isNicknameValid: Bool) {
    self.nickname = nickname
    self.pushOptIn = pushOptIn
    self.isNicknameValid = isNicknameValid
  }
}

/// 가입 시트에서 상세를 열 수 있는 약관
public enum LegalDocument: String, Equatable, Sendable {
  case terms
  case privacy

  /// 약관 기준 주소 뒤에 붙는 경로
  public var path: String { rawValue }
}
