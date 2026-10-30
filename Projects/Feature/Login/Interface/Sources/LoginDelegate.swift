//
//  LoginDelegate.swift
//  LoginInterface
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface
import ComposableArchitecture

@CasePathable
public enum LoginDelegate: Equatable, Sendable {
  case signedIn(AuthLoginResult)
}
