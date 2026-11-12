//
//  BearerRegisterDelegate.swift
//  BearerInterface
//
//  Created by FestiCore on 11/12/26.
//

import ComposableArchitecture

/// 코드 없는 깃발 프로필 등록(S14 D·E)이 부모에게 알리는 결과
@CasePathable
public enum BearerRegisterDelegate: Equatable, Sendable {
  /// 깃발을 만들었다. 부모가 고른 페스티벌을 핀한다.
  case registered(
    flagID: String,
    festivalID: String
  )
  /// 저장 완료(E1)의 '팩 받기'. 부모가 그 페스티벌 라이브 보드(팩 받기 카드)를 연다.
  case packRequested(festivalID: String)
  /// 저장 완료의 '완료'·'나중에 받을게요'
  case finished(festivalID: String)
  /// '초대 코드가 있어요'. 공동 기수는 원래 기수가 준 코드로 기존 코드 인증(S13 F~I)에서 등록한다.
  case claimRequested(festivalID: String)
  /// 뒤로. 부모가 한 단계 앞 화면(가입 직후면 기수 여부)으로 돌아간다.
  case backRequested
  /// '나중에 할게요'. 깃발을 만들지 않고 닫는다.
  case closeRequested
}
