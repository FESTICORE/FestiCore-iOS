//
//  BearerRoleChoiceDelegate.swift
//  BearerInterface
//
//  Created by FestiCore on 11/12/26.
//

import ComposableArchitecture

/// 기수 여부 고르기(S14 C)가 부모에게 알리는 결과
@CasePathable
public enum BearerRoleChoiceDelegate: Equatable, Sendable {
  /// '관객이에요'로 다음을 눌렀다.
  case audienceChosen
  /// '기수예요'로 다음을 눌렀다. 부모가 깃발 프로필 등록을 연다.
  case bearerChosen
  case closeRequested
}
