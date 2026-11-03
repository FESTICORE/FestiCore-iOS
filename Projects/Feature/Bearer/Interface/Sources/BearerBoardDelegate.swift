//
//  BearerBoardDelegate.swift
//  BearerInterface
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture

/// 기수 보드가 부모에게 알리는 결과
@CasePathable
public enum BearerBoardDelegate: Equatable, Sendable {
  /// "관객 화면으로"를 눌렀다.
  case closeRequested
}
