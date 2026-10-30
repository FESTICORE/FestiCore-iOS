//
//  FestiCoreAuth.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestiCoreStorageInterface

actor FestiCoreAuth: AuthService, AuthenticatedClientProvider {
  nonisolated let authenticatedClient: any FestiCoreNetworkClient
  private let store: GuardedCredentialStore
  private let credentials: any CredentialUpdating
  private let identityStorage: any SecureStorage

  init(
    authenticatedClient: any FestiCoreNetworkClient,
    store: GuardedCredentialStore,
    credentials: any CredentialUpdating,
    identityStorage: any SecureStorage
  ) {
    self.authenticatedClient = authenticatedClient
    self.store = store
    self.credentials = credentials
    self.identityStorage = identityStorage
  }

  var isLoggedIn: Bool { store.load() != nil }
  var refreshToken: String? { store.load()?.refreshToken }
  var currentUserID: String? {
    guard store.load() != nil else { return nil }
    return try? identityStorage.load(.sessionUserID)
  }

  func signIn(accessToken: String, refreshToken: String) {
    try? identityStorage.remove(.sessionUserID)
    store.allowSaves()
    let credential = FestiCoreCredential(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: JWTDecoder.decodeExpiration(accessToken)
    )
    store.save(credential)
    credentials.update(credential)
  }

  func rememberUserID(_ userID: String) {
    guard store.load() != nil, !userID.isEmpty else { return }
    try? identityStorage.save(userID, for: .sessionUserID)
  }

  func signOut() {
    store.clear()
    try? identityStorage.remove(.sessionUserID)
    credentials.update(nil)
  }

  func handleAuthFailure(for attempted: FestiCoreCredential) {
    guard store.load()?.refreshToken == attempted.refreshToken else { return }
    signOut()
    NotificationCenter.default.post(name: .festiCoreAuthSessionDidExpire, object: nil)
  }
}
