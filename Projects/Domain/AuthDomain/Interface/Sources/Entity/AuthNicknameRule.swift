//
//  AuthNicknameRule.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

/// 가입과 닉네임 변경이 함께 쓰는 닉네임 규칙. 앞뒤 공백을 뺀 길이로 판단한다.
public enum AuthNicknameRule {
  public static let lengthRange = 1 ... 12

  public static var maxLength: Int { lengthRange.upperBound }

  public static func trimmed(_ nickname: String) -> String {
    nickname.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public static func isValid(_ nickname: String) -> Bool {
    lengthRange.contains(trimmed(nickname).count)
  }
}
