//
//  KeychainCredentialStore.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import CryptoKit
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

  @discardableResult
  func save(_ credential: FestiCoreCredential) -> Bool {
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
      // 삭제가 일부 실패해도 기존 쌍을 다시 읽지 않도록 검증 값을 먼저 무효화한다.
      try? storage.save("invalid:\(UUID())", for: .credentialIntegrity)
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
    do {
      // 기존 설치의 토큰 쌍은 검증 값이 없을 수 있다. 새 저장부터 검증 값을 기록한다.
      if let integrity = try storage.load(.credentialIntegrity),
         integrity != integrityValue(accessToken: accessToken, refreshToken: refreshToken) {
        return nil
      }
    } catch { return nil }
    return FestiCoreCredential(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: JWTDecoder.decodeExpiration(accessToken)
    )
  }

  private func saveUnlocked(_ credential: FestiCoreCredential) -> Bool {
    // 첫 쓰기가 실패하면 기존 토큰은 건드리지 않는다.
    do { try storage.save("invalid:\(UUID())", for: .credentialIntegrity) }
    catch { return false }
    do {
      try storage.save(credential.accessToken, for: .accessToken)
      try storage.save(credential.refreshToken, for: .refreshToken)
      try storage.save(
        integrityValue(accessToken: credential.accessToken, refreshToken: credential.refreshToken),
        for: .credentialIntegrity
      )
      return true
    } catch {
      // 삭제까지 실패해도 invalid 검증 값이 혼합 토큰 쌍의 복원을 막는다.
      try? storage.remove(.accessToken)
      try? storage.remove(.refreshToken)
      return false
    }
  }

  private func integrityValue(accessToken: String, refreshToken: String) -> String {
    let value = "\(accessToken.utf8.count):\(accessToken)\(refreshToken)"
    let digest = SHA256.hash(data: Data(value.utf8))
    return "sha256:\(digest.map { String(format: "%02x", $0) }.joined())"
  }
}
