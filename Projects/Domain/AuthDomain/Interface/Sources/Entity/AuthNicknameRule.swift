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

  /// 입력을 받을 때 앞뒤 공백을 뺀 길이가 넘칠 때만 자른다. 단어 사이 공백 입력은 막지 않는다.
  public static func limited(_ input: String) -> String {
    let trimmedInput = trimmed(input)
    return trimmedInput.count > maxLength ? String(trimmedInput.prefix(maxLength)) : input
  }

  /// 입력란 라벨 옆에 보이는 글자 수. 앞뒤 공백은 세지 않는다.
  public static func counterText(_ input: String) -> String {
    "\(trimmed(input).count) / \(maxLength)"
  }
}
