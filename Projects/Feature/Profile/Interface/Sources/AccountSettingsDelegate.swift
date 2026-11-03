//
//  AccountSettingsDelegate.swift
//  ProfileInterface
//
//  Created by FestiCore on 11/3/26.
//

import AuthDomainInterface
import ComposableArchitecture

@CasePathable
public enum AccountSettingsDelegate: Equatable, Sendable {
  case backRequested
  case logoutRequested
  case withdrawRequested
  case refreshRequested
  case nicknameUpdated(AuthUser)
}
