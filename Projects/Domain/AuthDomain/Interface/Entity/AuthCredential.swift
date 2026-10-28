//
//  AuthCredential.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public enum AuthCredential: Sendable, Equatable {
  case google(idToken: String, serverAuthCode: String? = nil)
  case apple(idToken: String, authorizationCode: String, name: String? = nil)
}
