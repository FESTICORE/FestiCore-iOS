//
//  AuthDomainError.swift
//  FestiCoreAuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public enum AuthDomainError: Error, Sendable, Equatable {
  case invalidCredential
  case invalidResponse
  case configurationMissing
  case missingPresentingController
  case missingIDToken
  case missingAuthorizationCode
  case userCancelled
  case requestInProgress
  case providerFailure
}
