//
//  KeychainCredentialStore.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreNetworkInterface
import FestiCoreStorageInterface

final class KeychainCredentialStore: CredentialStore {
  private let storage: any SecureStorage
  private let lock = NSLock()
  private var currentRevision = UUID()

  init(storage: any SecureStorage) { self.storage = storage }

  func load() -> FestiCoreCredential? {
    lock.withLock { loadUnlocked() }
  }

  func save(_ credential: FestiCoreCredential) {
    _ = saveResult(credential)
  }

  @discardableResult
  func saveResult(_ credential: FestiCoreCredential) -> Bool {
    lock.withLock {
      let saved = saveUnlocked(credential)
      currentRevision = UUID()
      return saved
    }
  }

  func revision(matching current: FestiCoreCredential) -> UUID? {
    lock.withLock { loadUnlocked() == current ? currentRevision : nil }
  }

  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) -> Bool {
    lock.withLock {
      guard currentRevision == revision, loadUnlocked() == current else { return false }
      guard saveUnlocked(credential) else {
        currentRevision = UUID()
        return false
      }
      currentRevision = UUID()
      return true
    }
  }

  func clear() {
    lock.withLock {
      try? storage.remove(.accessToken)
      try? storage.remove(.refreshToken)
      try? storage.remove(.sessionUserID)
      currentRevision = UUID()
    }
  }

  private func loadUnlocked() -> FestiCoreCredential? {
    guard let accessToken = try? storage.load(.accessToken), !accessToken.isEmpty,
          let refreshToken = try? storage.load(.refreshToken), !refreshToken.isEmpty
    else { return nil }
    return FestiCoreCredential(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: JWTDecoder.decodeExpiration(accessToken)
    )
  }

  private func saveUnlocked(_ credential: FestiCoreCredential) -> Bool {
    do {
      try storage.save(credential.accessToken, for: .accessToken)
      try storage.save(credential.refreshToken, for: .refreshToken)
      return true
    } catch {
      // 둘 중 하나라도 실패하면 서로 다른 세션의 토큰 쌍이 남지 않도록 지운다.
      try? storage.remove(.accessToken)
      try? storage.remove(.refreshToken)
      return false
    }
  }
}
