//
//  SettingsHomeDelegate.swift
//  ProfileInterface
//
//  Created by FestiCore on 11/12/26.
//

import AuthDomainInterface
import ComposableArchitecture

/// S13-0 설정 홈이 마이 화면에 알리는 결과. 계정 요청은 마이를 거쳐 앱으로 간다.
@CasePathable
public enum SettingsHomeDelegate: Equatable, Sendable {
  case backRequested
  case logoutRequested
  case withdrawRequested
  case profileRefreshRequested
  case profileUpdated(AuthUser)
}
