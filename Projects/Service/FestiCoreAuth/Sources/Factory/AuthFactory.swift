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
    baseURL: URL? = NetworkClientFactory.bundleBaseURL,
    revocationJournalURL: URL? = nil
  ) -> any AuthService & AuthenticatedClientProvider {
    let journal = SessionRevocationJournal(url: revocationJournalURL ?? defaultRevocationJournalURL)
    let base = KeychainCredentialStore(storage: storage, journal: journal)
    let store = GuardedCredentialStore(
      base: base,
      recoverInitialCredential: base.initialJournalUnreadable
    )
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
      identityStorage: storage,
      journal: journal,
      initialJournalUnreadable: base.initialJournalUnreadable
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

  private static var defaultRevocationJournalURL: URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Library/Application Support", isDirectory: true)
    return support.appendingPathComponent("FestiCore/session-revocation", isDirectory: false)
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
