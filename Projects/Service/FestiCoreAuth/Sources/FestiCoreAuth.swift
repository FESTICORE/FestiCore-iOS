//
//  FestiCoreAuth.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreAuthInterface
import FestiCoreNetworkInterface

actor FestiCoreAuth: AuthService, AuthenticatedClientProvider {
  nonisolated let authenticatedClient: any FestiCoreNetworkClient
  private let store: GuardedCredentialStore
  private let credentials: any CredentialUpdating

  init(
    authenticatedClient: any FestiCoreNetworkClient,
    store: GuardedCredentialStore,
    credentials: any CredentialUpdating
  ) {
    self.authenticatedClient = authenticatedClient
    self.store = store
    self.credentials = credentials
  }

  var isLoggedIn: Bool { store.load() != nil }
  var refreshToken: String? { store.load()?.refreshToken }

  func signIn(accessToken: String, refreshToken: String) {
    store.allowSaves()
    let credential = FestiCoreCredential(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: JWTDecoder.decodeExpiration(accessToken)
    )
    store.save(credential)
    credentials.update(credential)
  }

  func signOut() {
    store.clear()
    credentials.update(nil)
  }

  func handleAuthFailure(for attempted: FestiCoreCredential) {
    guard store.load()?.refreshToken == attempted.refreshToken else { return }
    signOut()
    NotificationCenter.default.post(name: .festiCoreAuthSessionDidExpire, object: nil)
  }
}
