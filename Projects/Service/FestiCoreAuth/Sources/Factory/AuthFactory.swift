//
//  AuthFactory.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import os
import FestiCoreAuthInterface
import FestiCoreNetwork
import FestiCoreNetworkInterface
import FestiCoreStorageInterface

public enum AuthFactory {
  public static func make(
    refreshClient: any FestiCoreNetworkClient,
    storage: any SecureStorage,
    baseURL: URL? = NetworkClientFactory.bundleBaseURL
  ) -> any AuthService & AuthenticatedClientProvider {
    let store = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    let relay = AuthFailureRelay()
    let authenticated = NetworkClientFactory.unified(
      store: store,
      refresher: TokenRefresher(client: refreshClient) { credential in
        await relay.fire(for: credential)
      },
      baseURL: baseURL
    )
    let auth = FestiCoreAuth(
      authenticatedClient: authenticated.client,
      store: store,
      credentials: authenticated.credentials,
      identityStorage: storage
    )
    relay.set { [weak auth] credential in
      await auth?.handleAuthFailure(for: credential)
    }
    store.setPersistenceFailureHandler { [weak auth, credentials = authenticated.credentials] in
      credentials.update(nil)
      Task { await auth?.handlePersistenceFailure() }
    }
    return auth
  }
}

private final class AuthFailureRelay: Sendable {
  private let handler = OSAllocatedUnfairLock<(@Sendable (FestiCoreCredential) async -> Void)?>(initialState: nil)

  func set(_ handler: @escaping @Sendable (FestiCoreCredential) async -> Void) {
    self.handler.withLock { $0 = handler }
  }

  func fire(for credential: FestiCoreCredential) async {
    let handler = handler.withLock { $0 }
    await handler?(credential)
  }
}
