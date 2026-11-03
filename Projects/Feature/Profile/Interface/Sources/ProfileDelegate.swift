//
//  ProfileDelegate.swift
//  ProfileInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

import AuthDomainInterface

@CasePathable
public enum ProfileDelegate: Equatable, Sendable {
  case bearerRequested
  case searchRequested
  case loginRequested
  case profileRefreshRequested
  case logoutRequested
  case withdrawRequested
  /// 닉네임을 바꿔 세션의 표시 이름을 갱신해야 한다.
  case profileUpdated(AuthUser)
}
