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
  /// 코디네이터가 로그인을 수락하기 전까지 Keychain에 쓰지 않는 세션.
  private var staged: StagedSession?
  /// 이번 실행에서 확정한 세션의 식별자. 닫힌 로그인의 세션만 되돌릴 때 쓴다.
  private var committedSessionID: UUID?

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
    guard let credential = store.load(),
          let stored = try? identityStorage.load(.sessionUserID),
          stored == JWTDecoder.decodeSubject(credential.accessToken)
    else { return nil }
    return stored
  }

  func stageSession(accessToken: String, refreshToken: String) -> UUID {
    let id = UUID()
    staged = StagedSession(
      id: id,
      credential: FestiCoreCredential(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: JWTDecoder.decodeExpiration(accessToken)
      )
    )
    return id
  }

  func commitSession(_ id: UUID) -> Bool {
    guard let session = staged, session.id == id else { return false }
    staged = nil
    try? identityStorage.remove(.sessionUserID)
    store.allowSaves()
    guard store.save(session.credential) else {
      clearCommittedSession()
      return false
    }
    credentials.update(session.credential)
    committedSessionID = session.id
    if let userID = session.userID {
      try? identityStorage.save(userID, for: .sessionUserID)
    }
    return true
  }

  func discardSession(_ id: UUID) -> Bool {
    guard staged?.id == id else { return false }
    staged = nil
    return true
  }

  func rememberUserID(_ userID: String) {
    if var session = staged {
      // 임시 세션의 계정은 확정 세션과 다를 수 있어 임시 토큰으로 검증하고 확정 때 저장한다.
      guard userID == JWTDecoder.decodeSubject(session.credential.accessToken) else { return }
      session.userID = userID
      staged = session
      return
    }
    guard let credential = store.load(),
          userID == JWTDecoder.decodeSubject(credential.accessToken)
    else { return }
    try? identityStorage.save(userID, for: .sessionUserID)
  }

  func signOut() -> Bool {
    staged = nil
    return clearCommittedSession()
  }

  func signOut(ifSession id: UUID) -> Bool {
    guard committedSessionID == id else { return false }
    return clearCommittedSession()
  }

  func handleAuthFailure(for attempted: FestiCoreCredential) {
    guard store.load()?.refreshToken == attempted.refreshToken else { return }
    // 기존 세션의 자동 만료는 진행 중인 새 로그인의 임시 세션까지 무효로 만들지 않는다.
    clearCommittedSession()
    NotificationCenter.default.post(name: .festiCoreAuthSessionDidExpire, object: nil)
  }

  func handlePersistenceFailure() {
    guard store.load() == nil else { return }
    committedSessionID = nil
    try? identityStorage.remove(.sessionUserID)
    credentials.update(nil)
    NotificationCenter.default.post(name: .festiCoreAuthSessionDidExpire, object: nil)
  }
}

private extension FestiCoreAuth {
  @discardableResult
  func clearCommittedSession() -> Bool {
    let cleared = store.clear()
    if cleared { committedSessionID = nil }
    try? identityStorage.remove(.sessionUserID)
    credentials.update(nil)
    return cleared
  }
}

private struct StagedSession {
  let id: UUID
  let credential: FestiCoreCredential
  var userID: String?
}
