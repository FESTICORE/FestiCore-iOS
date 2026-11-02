//
//  BearerProfileDelegate.swift
//  BearerInterface
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture

/// 깃발 프로필 화면이 부모에게 알리는 결과
@CasePathable
public enum BearerProfileDelegate: Equatable, Sendable {
  /// 저장 완료 화면에서 완료를 눌렀다.
  case finished(flagID: String)
  case closeRequested
}
