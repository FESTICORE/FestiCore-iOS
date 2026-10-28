//
//  AuthAPI.swift
//  FestiCoreAPI
//
//  Created by FestiCore on 10/29/26.
//

public enum AuthAPI: String, CaseIterable, Sendable {
  case login
  case refresh
  case logout

  public var path: String { "api/v1/auth/\(rawValue)" }
}
