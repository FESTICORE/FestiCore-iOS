//
//  AuthDomainError.swift
//  FestiCoreAuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public enum AuthDomainError: Error, Sendable {
  case invalidCredential
  case invalidResponse
}
