//
//  ProfileDelegate.swift
//  ProfileInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

@CasePathable
public enum ProfileDelegate: Equatable, Sendable {
  case bearerRequested
  case searchRequested
  case packRequested(String)
  case lockScreenRequested
  case loginRequested
  case profileRefreshRequested
  case logoutRequested
  case withdrawRequested
  case noticeRequested
}
