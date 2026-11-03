//
//  BearerClaimDelegate.swift
//  BearerInterface
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture

/// 기수 인증 코드 화면이 부모에게 알리는 결과
@CasePathable
public enum BearerClaimDelegate: Equatable, Sendable {
  /// 코드가 맞아 기수가 됐다. 부모는 깃발 프로필 화면을 연다.
  case claimed(festivalID: String, claim: BearerClaim)
  case closeRequested
}
