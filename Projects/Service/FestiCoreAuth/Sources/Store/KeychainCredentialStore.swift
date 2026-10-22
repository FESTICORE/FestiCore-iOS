//
//  KeychainCredentialStore.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import FestiCoreNetworkInterface
import FestiCoreStorageInterface

final class KeychainCredentialStore: CredentialStore {
  private let storage: any SecureStorage

  init(storage: any SecureStorage) { self.storage = storage }

  func load() -> FestiCoreCredential? {
    guard let accessToken = try? storage.load(.accessToken), !accessToken.isEmpty,
          let refreshToken = try? storage.load(.refreshToken), !refreshToken.isEmpty
    else { return nil }
    return FestiCoreCredential(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: JWTDecoder.decodeExpiration(accessToken)
    )
  }

  func save(_ credential: FestiCoreCredential) {
    try? storage.save(credential.accessToken, for: .accessToken)
    try? storage.save(credential.refreshToken, for: .refreshToken)
  }

  func clear() {
    try? storage.remove(.accessToken)
    try? storage.remove(.refreshToken)
  }
}
