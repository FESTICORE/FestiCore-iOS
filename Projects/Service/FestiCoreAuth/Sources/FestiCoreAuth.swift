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
  private let journal: SessionRevocationJournal
  private var revocationInFlight = false
  private var initialJournalRecoveryPending: Bool
  /// 코디네이터가 로그인을 수락하기 전까지 Keychain에 쓰지 않는 세션.
  private var staged: StagedSession?
  /// 이번 실행에서 확정한 세션의 식별자. 닫힌 로그인의 세션만 되돌릴 때 쓴다.
  private var committedSessionID: UUID?
  /// 키체인 삭제 실패 뒤 서버에서 끝난 세션의 로컬 정리가 남아 있다.
  private var sessionClearPending = false
  private var withdrawalCleanupPending = false

  init(
    authenticatedClient: any FestiCoreNetworkClient,
    store: GuardedCredentialStore,
    credentials: any CredentialUpdating,
    identityStorage: any SecureStorage,
    journal: SessionRevocationJournal,
    initialJournalUnreadable: Bool
  ) {
    self.authenticatedClient = authenticatedClient
    self.store = store
    self.credentials = credentials
    self.identityStorage = identityStorage
    self.journal = journal
    initialJournalRecoveryPending = initialJournalUnreadable
  }

  var isLoggedIn: Bool { recoveredCredential() != nil || sessionClearPending }
  var sessionID: UUID { store.sessionID }
  var authenticatedSessionID: UUID? { store.sessionSnapshot()?.id }
  var hasPendingLocalClear: Bool {
    if case .pending(.sessionExpired) = journal.status { return true }
    return sessionClearPending
  }
  var hasPendingWithdrawalCleanup: Bool {
    if case .pending(.withdrawalCompleted) = journal.status { return true }
    return withdrawalCleanupPending
  }
  var hasPendingSignOutCleanup: Bool {
    guard case .pending(.signOutConfirmed) = journal.status else { return false }
    return sessionClearPending || store.load() == nil
  }
  var hasPendingWithdrawalAuthorizationCleanup: Bool {
    guard case .pending(.withdrawalAuthorizationRejected) = journal.status else { return false }
    return sessionClearPending || store.load() == nil
  }
  var hasUnconfirmedRevocation: Bool {
    switch journal.status {
    case .pending(.signOutRequested), .pending(.withdrawalRequested), .unreadable:
      return store.load() == nil
    case .absent, .pending: return false
    }
  }
  var refreshToken: String? { recoveredCredential()?.refreshToken }
  var currentUserID: String? {
    guard let credential = recoveredCredential(),
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
    switch journal.status {
    case .absent: break
    case .pending: guard !revocationInFlight else { return false }
    case .unreadable: return false
    }
    staged = nil
    try? identityStorage.remove(.sessionUserID)
    store.allowSaves()
    guard store.save(session.credential) else {
      clearCommittedSession()
      return false
    }
    guard journal.clear() else {
      clearCommittedSession()
      return false
    }
    credentials.update(session.credential)
    initialJournalRecoveryPending = false
    committedSessionID = session.id
    sessionClearPending = false
    withdrawalCleanupPending = false
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
    guard let credential = recoveredCredential(),
          userID == JWTDecoder.decodeSubject(credential.accessToken)
    else { return }
    try? identityStorage.save(userID, for: .sessionUserID)
  }

  func signOut() -> Bool {
    let requestIsInFlight = revocationInFlight
    let requestIsUnconfirmed = requestIsInFlight && journal.hasRequestedRevocation
    if !requestIsInFlight { staged = nil }
    let cleared = clearCommittedSession()
    if !requestIsUnconfirmed { revocationInFlight = false }
    sessionClearPending = !cleared
    if cleared { withdrawalCleanupPending = false }
    return cleared
  }

  func prepareRevocation(_ kind: AuthRevocationKind, ifSessionIDMatches sessionID: UUID) -> Bool {
    guard !revocationInFlight, store.sessionSnapshot()?.id == sessionID else { return false }
    let requested: SessionRevocationJournal.State
    switch kind {
    case .signOut: requested = .signOutRequested
    case .withdrawal: requested = .withdrawalRequested
    }
    switch journal.status {
    case .absent:
      let recorded = journal.record(requested)
      if recorded { revocationInFlight = true }
      return recorded
    case let .pending(state) where state == requested:
      guard store.load() != nil, !sessionClearPending else { return false }
      revocationInFlight = true
      return true
    case .pending, .unreadable: return false
    }
  }

  func finishRevocationRequest() { revocationInFlight = false }

  func retryUnconfirmedLocalCleanup() -> Bool {
    guard hasUnconfirmedRevocation else { return false }
    return clearCredentialPreservingJournal()
  }

  func confirmSignOut() -> Bool { journal.record(.signOutConfirmed) }

  func confirmWithdrawalAuthorizationRejected() -> Bool {
    journal.record(.withdrawalAuthorizationRejected)
  }

  func completeWithdrawal() -> Bool {
    withdrawalCleanupPending = true
    guard journal.record(.withdrawalCompleted) else {
      // 서버 성공은 이 실행에서만 알고 있다. 저널을 지우지 않은 채 로컬 토큰부터 폐기한다.
      _ = clearCredentialPreservingJournal()
      revocationInFlight = false
      return false
    }
    return signOut()
  }

  func signOut(ifSession id: UUID) -> Bool {
    guard committedSessionID == id else { return false }
    let cleared = clearCommittedSession()
    sessionClearPending = !cleared
    if cleared { withdrawalCleanupPending = false }
    return cleared
  }

  func signOut(ifSessionIDMatches sessionID: UUID) -> Bool {
    guard store.sessionSnapshot()?.id == sessionID else { return false }
    let cleared = clearCommittedSession()
    sessionClearPending = !cleared
    if cleared { withdrawalCleanupPending = false }
    return cleared
  }

  func handleAuthFailure(for attempted: FestiCoreCredential, sessionID: UUID) {
    guard let session = store.sessionSnapshot(),
          session.id == sessionID,
          session.credential.refreshToken == attempted.refreshToken
    else { return }
    // 기존 세션의 자동 만료는 진행 중인 새 로그인의 임시 세션까지 무효로 만들지 않는다.
    // 만료된 토큰의 Keychain 삭제가 실패해도 다음 실행에서 복원하지 않는다.
    // 진행 중인 서버 요청의 결과 기록은 덮어쓰지 않는다.
    if case .absent = journal.status { _ = journal.record(.sessionExpired) }
    let cleared = clearCommittedSession()
    sessionClearPending = !cleared
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
  func clearCredentialPreservingJournal() -> Bool {
    let cleared = store.clear()
    if cleared { committedSessionID = nil }
    try? identityStorage.remove(.sessionUserID)
    credentials.update(nil)
    sessionClearPending = !cleared
    return cleared
  }

  func recoveredCredential() -> FestiCoreCredential? {
    guard let credential = store.load() else { return nil }
    if initialJournalRecoveryPending {
      credentials.update(credential)
      initialJournalRecoveryPending = false
    }
    return credential
  }

  @discardableResult
  func clearCommittedSession() -> Bool {
    let keychainCleared = store.clear()
    // 서버 응답 전 토큰 갱신 실패로 로컬 토큰이 지워져도 요청 결과 기록은 보존한다.
    let preserveRequest = revocationInFlight && journal.hasRequestedRevocation
    let cleared = keychainCleared && (preserveRequest || journal.clear())
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
