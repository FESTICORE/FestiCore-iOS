//
//  AuthUser.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

public struct AuthUser: Sendable, Equatable {
  public let id: String
  public let provider: String
  public let email: String?
  public let nickname: String?
  public let nicknameConfirmed: Bool
  public let termsAcceptedAt: String?
  public let termsVersion: String?
  public let pushOptIn: Bool
  public let profileImageURL: String?

  public init(
    id: String,
    provider: String,
    email: String?,
    nickname: String?,
    nicknameConfirmed: Bool,
    termsAcceptedAt: String?,
    termsVersion: String?,
    pushOptIn: Bool,
    profileImageURL: String?
  ) {
    self.id = id
    self.provider = provider
    self.email = email
    self.nickname = nickname
    self.nicknameConfirmed = nicknameConfirmed
    self.termsAcceptedAt = termsAcceptedAt
    self.termsVersion = termsVersion
    self.pushOptIn = pushOptIn
    self.profileImageURL = profileImageURL
  }
}
