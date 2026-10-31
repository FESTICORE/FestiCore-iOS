//
//  AuthTests.swift
//  FestiCoreAuthTests
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import os
import Testing
import APIEndpoint
import FestiCoreAuthInterface
import FestiCoreNetwork
import FestiCoreNetworkInterface
import FestiCoreStorageInterface
@testable import FestiCoreAuth

@Suite("FestiCore 인증 서비스")
struct AuthTests {
  private let old = FestiCoreCredential(accessToken: "old", refreshToken: "old-refresh")
  private let successBody = Data("""
    {"code":"SUCCESS","data":{"accessToken":"new","refreshToken":"new-refresh"},"message":"성공"}
    """.utf8)

  @Test("갱신 응답에서 새 토큰 쌍을 반환한다")
  func refreshSuccess() async throws {
    let recorder = FailureRecorder()
    let client = StubRefreshClient(result: .success(successBody))
    let refresher = TokenRefresher(client: client) { _, _ in
      await recorder.record()
    }

    let renewed = try await refresher.refresh(old, sessionID: UUID())

    #expect(renewed.accessToken == "new")
    #expect(renewed.refreshToken == "new-refresh")
    #expect(await recorder.count == 0)
    #expect(client.lastRequest?.path == "api/v1/auth/refresh")
    #expect(client.lastRequest?.authorization == FestiCoreAuthorization.none)
    #expect(client.lastRequest?.refreshToken == "old-refresh")
  }

  @Test("401만 인증 만료를 전달한다", arguments: [401, 500])
  func refreshResponseFailure(status: Int) async {
    let recorder = FailureRecorder()
    let client = StubRefreshClient(result: .failure(.response(ResponseError(httpStatus: status))))
    let refresher = TokenRefresher(client: client) { _, _ in
      await recorder.record()
    }

    do {
      _ = try await refresher.refresh(old, sessionID: UUID())
      Issue.record("실패 응답을 전파해야 한다")
    } catch {
      guard case let FestiCoreNetworkError.response(response) = error else {
        Issue.record("응답 오류 기대: \(error)")
        return
      }
      #expect(response.httpStatus == status)
    }
    #expect(await recorder.count == (status == 401 ? 1 : 0))
  }

  @Test("전송 실패 시 세션을 종료하지 않는다")
  func refreshTransportFailure() async {
    let recorder = FailureRecorder()
    let client = StubRefreshClient(result: .failure(.transport(.notConnected)))
    let refresher = TokenRefresher(client: client) { _, _ in
      await recorder.record()
    }

    do {
      _ = try await refresher.refresh(old, sessionID: UUID())
      Issue.record("전송 실패를 전파해야 한다")
    } catch {
      guard case FestiCoreNetworkError.transport(.notConnected) = error else {
        Issue.record("전송 오류 기대: \(error)")
        return
      }
    }
    #expect(await recorder.count == 0)
  }

  @Test("토큰 회전과 로그아웃은 저장소와 동일한 인증 세션을 갱신한다")
  func authFactorySessionLifecycle() async {
    let storage = MemorySecureStorage()
    let refreshClient = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(
      refreshClient: refreshClient,
      storage: storage,
      baseURL: URL(string: "https://festicore.test"),
      revocationJournalURL: storage.journalURL
    )
    let client = auth.authenticatedClient
    #expect((client as AnyObject) === (auth.authenticatedClient as AnyObject))

    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "old-refresh")
    await auth.rememberUserID("user-a")
    #expect(await auth.currentUserID == "user-a")
    #expect(storage.load(.accessToken) == jwt(subject: "user-a"))
    #expect(storage.load(.refreshToken) == "old-refresh")

    let restored = AuthFactory.make(refreshClient: refreshClient, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restored.currentUserID == "user-a")

    await signIn(auth, accessToken: jwt(subject: "user-b"), refreshToken: "new-refresh")
    #expect(await auth.currentUserID == nil)
    await auth.rememberUserID("user-b")
    #expect(await auth.currentUserID == "user-b")
    #expect(storage.load(.accessToken) == jwt(subject: "user-b"))
    #expect(storage.load(.refreshToken) == "new-refresh")

    await auth.signOut()
    #expect(await auth.isLoggedIn == false)
    #expect(storage.load(.accessToken) == nil)
    #expect(storage.load(.refreshToken) == nil)
    #expect(storage.load(.sessionUserID) == nil)
    #expect(await auth.currentUserID == nil)
  }

  @Test("이전 사용자 ID 삭제 실패와 새 ID 저장 실패 시 다른 계정의 찜을 보여주지 않는다")
  func failedIdentityWritesDoNotExposePreviousAccount() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)

    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")
    #expect(await auth.currentUserID == "user-a")

    storage.failIdentityRemoval = true
    storage.failIdentitySave = true
    await signIn(auth, accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")
    #expect(storage.load(.sessionUserID) == "user-a")
    #expect(await auth.currentUserID == nil)
    await auth.rememberUserID("user-b")
    #expect(await auth.currentUserID == nil)

    storage.failIdentitySave = false
    await auth.rememberUserID("user-b")
    #expect(await auth.currentUserID == "user-b")
    await auth.signOut()
    #expect(await auth.currentUserID == nil)
  }

  @Test("정상 토큰 갱신 뒤에도 검증된 계정 ID를 복구한다")
  func refreshedTokenKeepsVerifiedIdentity() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let oldToken = jwt(subject: "user-a")
    let newToken = jwt(subject: "user-a", suffix: "renewed")
    await signIn(auth, accessToken: oldToken, refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")
    let sessionID = await auth.sessionID

    let credentialStore = KeychainCredentialStore(storage: storage)
    let oldCredential = try #require(credentialStore.load())
    let revision = try #require(credentialStore.revision(matching: oldCredential))
    #expect(try credentialStore.replace(
      FestiCoreCredential(accessToken: newToken, refreshToken: "refresh-a-rotated"),
      ifCurrent: oldCredential,
      revision: revision
    ))
    #expect(await auth.currentUserID == "user-a")
    #expect(await auth.sessionID == sessionID)
    let restored = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restored.currentUserID == "user-a")
  }

  @Test("이전 로그인 식별자로 새 세션을 지울 수 없다")
  func staleSessionCannotSignOutNewLogin() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage)
    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    let oldSessionID = await auth.sessionID

    await signIn(auth, accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")
    #expect(await auth.signOut(ifSessionIDMatches: oldSessionID) == false)
    #expect(await auth.isLoggedIn)
    #expect(await auth.refreshToken == "refresh-b")
  }

  @Test("기존 세션의 조건부 로그아웃은 진행 중인 새 로그인을 폐기하지 않는다")
  func conditionalSignOutKeepsStagedSession() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage)
    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    let oldSessionID = await auth.sessionID
    let next = await auth.stageSession(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")

    #expect(await auth.signOut(ifSessionIDMatches: oldSessionID))
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.commitSession(next))
    #expect(await auth.refreshToken == "refresh-b")
  }

  @Test("로그아웃 뒤 늦게 도착한 갱신 결과를 저장하지 않는다")
  func lateRefreshCannotRestoreLoggedOutSession() {
    let storage = MemorySecureStorage()
    let base = KeychainCredentialStore(storage: storage)
    let guarded = GuardedCredentialStore(base: base)
    guarded.allowSaves()
    guarded.save(old)
    guarded.clear()
    guarded.save(FestiCoreCredential(accessToken: "late", refreshToken: "late-refresh"))

    #expect(guarded.load() == nil)
    #expect(storage.load(.accessToken) == nil)
  }

  @Test("키체인 무효화와 삭제가 모두 실패하면 로그아웃 완료를 반환하지 않는다")
  func failedClearReportsRestorableSession() {
    let storage = MemorySecureStorage()
    let guarded = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    guarded.allowSaves()
    #expect(guarded.save(old))
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]
    storage.failIdentityRemoval = true

    #expect(guarded.clear() == false)
    #expect(guarded.load() == nil)
    #expect(KeychainCredentialStore(storage: storage).load() == old)
  }

  @Test("인증 서비스는 키체인 삭제 실패를 로그아웃 성공으로 보고하지 않는다")
  func signOutReportsKeychainFailure() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]
    storage.failIdentityRemoval = true

    #expect(await auth.signOut() == false)
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.hasPendingLocalClear)
    #expect(await auth.refreshToken == nil)
    #expect(await auth.hasPendingWithdrawalCleanup == false)
    #expect(KeychainCredentialStore(storage: storage).load() == old)

    storage.failTokenSaveFor = nil
    storage.failTokenRemovalFor = []
    storage.failIdentityRemoval = false
    #expect(await auth.signOut())
    #expect(await auth.isLoggedIn == false)
    #expect(KeychainCredentialStore(storage: storage).load() == nil)
  }

  @Test("탈퇴 후 로컬 삭제 실패만 탈퇴 정리 재시도 상태로 남긴다")
  func withdrawalCleanupIsTrackedSeparately() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]

    #expect(await auth.completeWithdrawal() == false)
    #expect(await auth.hasPendingWithdrawalCleanup)
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.refreshToken == nil)

    storage.failTokenSaveFor = nil
    storage.failTokenRemovalFor = []
    #expect(await auth.completeWithdrawal())
    #expect(await auth.hasPendingWithdrawalCleanup == false)
    #expect(await auth.isLoggedIn == false)
  }

  @Test("탈퇴 완료 뒤 키체인 삭제가 실패해도 새 인증 객체는 이전 토큰을 복원하지 않는다")
  func withdrawalJournalSurvivesAuthRecreation() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    #expect(await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: await auth.sessionID))
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]
    storage.failIdentityRemoval = true
    #expect(await auth.completeWithdrawal() == false)
    #expect(storage.load(.accessToken) == old.accessToken)
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path))

    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.isLoggedIn == false)
    #expect(await restarted.refreshToken == nil)
    #expect(await restarted.hasPendingWithdrawalCleanup)
    #expect(await restarted.completeWithdrawal() == false)

    storage.failTokenSaveFor = nil
    storage.failTokenRemovalFor = []
    storage.failIdentityRemoval = false
    #expect(await restarted.completeWithdrawal())
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path) == false)
    #expect(storage.load(.accessToken) == nil)
  }

  @Test("로그아웃 삭제 실패 뒤 재시작해도 토큰을 복원하지 않고 로컬 정리를 재시도한다")
  func signOutJournalSurvivesAuthRecreation() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    #expect(await auth.prepareRevocation(.signOut, ifSessionIDMatches: await auth.sessionID))
    #expect(await auth.confirmSignOut())
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]
    #expect(await auth.signOut() == false)

    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.isLoggedIn == false)
    #expect(await restarted.hasPendingSignOutCleanup)
    storage.failTokenSaveFor = nil
    storage.failTokenRemovalFor = []
    #expect(await restarted.signOut())
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path) == false)
  }

  @Test("탈퇴 401 뒤 로컬 삭제 실패도 재시작 후 로컬 정리 상태로 남는다")
  func withdrawalAuthorizationCleanupSurvivesRestart() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    #expect(await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: await auth.sessionID))
    #expect(await auth.confirmWithdrawalAuthorizationRejected())
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]
    #expect(await auth.signOut() == false)

    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.hasPendingWithdrawalAuthorizationCleanup)
    storage.failTokenSaveFor = nil
    storage.failTokenRemovalFor = []
    #expect(await restarted.signOut())
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path) == false)
  }

  @Test("서버 응답 전 재시작한 요청은 로컬 정리 완료로 취급하지 않는다")
  func requestedRevocationAfterCrashIsUnconfirmed() async {
    for kind in [AuthRevocationKind.signOut, .withdrawal] {
      let storage = MemorySecureStorage()
      let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
      let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
      #expect(await auth.prepareRevocation(kind, ifSessionIDMatches: await auth.sessionID))

      let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      #expect(await restarted.isLoggedIn == false)
      #expect(await restarted.hasUnconfirmedRevocation)
      #expect(await restarted.hasPendingSignOutCleanup == false)
      #expect(await restarted.hasPendingWithdrawalAuthorizationCleanup == false)
      #expect(await restarted.hasPendingWithdrawalCleanup == false)
    }
  }

  @Test("탈퇴 200 뒤 완료 기록 실패는 토큰을 폐기하고 재시작 뒤 로컬 삭제만 재시도한다")
  func failedWithdrawalCompletionJournalKeepsLocalCleanupAvailable() async throws {
    for clearFails in [false, true] {
      let storage = MemorySecureStorage()
      let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
      let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
      #expect(await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: await auth.sessionID))

      try FileManager.default.removeItem(at: storage.journalURL)
      try FileManager.default.createDirectory(at: storage.journalURL, withIntermediateDirectories: false)
      if clearFails {
        storage.failTokenSaveFor = .credentialIntegrity
        storage.failTokenRemovalFor = [.accessToken, .refreshToken]
      }
      #expect(await auth.completeWithdrawal() == false)
      #expect(storage.load(.accessToken) == (clearFails ? old.accessToken : nil))

      let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      #expect(await restarted.isLoggedIn == false)
      #expect(await restarted.hasUnconfirmedRevocation)
      if clearFails {
        #expect(await restarted.retryUnconfirmedLocalCleanup() == false)
        storage.failTokenSaveFor = nil
        storage.failTokenRemovalFor = []
      }
      #expect(await restarted.retryUnconfirmedLocalCleanup())
      #expect(storage.load(.accessToken) == nil)
      #expect(storage.load(.refreshToken) == nil)
      #expect(await restarted.hasUnconfirmedRevocation)

      try FileManager.default.removeItem(at: storage.journalURL)
      let newSession = await restarted.stageSession(accessToken: "new-access", refreshToken: "new-refresh")
      #expect(await restarted.commitSession(newSession))
      #expect(await restarted.refreshToken == "new-refresh")
    }
  }

  @Test("서버 응답 전 로컬 토큰 삭제가 먼저 일어나도 요청 결과 기록은 남는다")
  func localClearDuringRequestKeepsUnconfirmedJournal() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let id = await auth.stageSession(accessToken: old.accessToken, refreshToken: old.refreshToken)
    #expect(await auth.commitSession(id))
    #expect(await auth.prepareRevocation(.signOut, ifSessionIDMatches: await auth.sessionID))
    #expect(await auth.signOut(ifSession: id))

    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.hasUnconfirmedRevocation)
    #expect(await restarted.hasPendingSignOutCleanup == false)
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path))
  }

  @Test("탈퇴 중 일반 로그아웃은 요청 잠금과 다음 로그인 세션을 보존한다")
  func localSignOutDuringWithdrawalPreservesNewSession() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: "account-a", refreshToken: "refresh-a")
    #expect(await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: await auth.sessionID))

    let newSession = await auth.stageSession(accessToken: "account-b", refreshToken: "refresh-b")
    #expect(await auth.signOut()) // 다른 API의 401이 기존 세션만 지운 상황
    #expect(await auth.hasUnconfirmedRevocation)
    #expect(await auth.commitSession(newSession) == false)
    #expect(await auth.completeWithdrawal()) // 늦게 도착한 기존 세션의 탈퇴 성공
    #expect(await auth.commitSession(newSession))
    #expect(await auth.refreshToken == "refresh-b")
    #expect(storage.load(.refreshToken) == "refresh-b")
  }

  @Test("로그아웃 확인 기록 실패 뒤 요청 잠금은 종료할 수 있다")
  func failedConfirmationCanFinishRequest() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    #expect(await auth.prepareRevocation(.signOut, ifSessionIDMatches: await auth.sessionID))
    try FileManager.default.removeItem(at: storage.journalURL)
    try FileManager.default.createDirectory(at: storage.journalURL, withIntermediateDirectories: false)
    #expect(await auth.confirmSignOut() == false)
    await auth.finishRevocationRequest()
    try FileManager.default.removeItem(at: storage.journalURL)
    #expect(await auth.prepareRevocation(.signOut, ifSessionIDMatches: await auth.sessionID))
  }

  @Test("저널 파일을 쓸 수 없으면 서버 요청 준비가 실패하고 토큰은 유지된다")
  func journalWriteFailureRejectsRevocation() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    try FileManager.default.createDirectory(at: storage.journalURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storage.journalURL) }

    #expect(await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: await auth.sessionID) == false)
    #expect(await auth.isLoggedIn)
    #expect(storage.load(.accessToken) == old.accessToken)
  }

  @Test("손상된 저널도 새 실행의 토큰 복원을 거부한다")
  func unreadableJournalBlocksRestoration() async throws {
    let storage = MemorySecureStorage()
    let store = KeychainCredentialStore(storage: storage)
    #expect(store.save(old))
    try FileManager.default.createDirectory(
      at: storage.journalURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("invalid".utf8).write(to: storage.journalURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: storage.journalURL.deletingLastPathComponent()) }
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.isLoggedIn == false)
    #expect(await restarted.refreshToken == nil)
  }

  @Test("요청 기록 뒤 재시작해도 명시적 새 로그인으로 세션을 안전하게 교체한다")
  func newLoginReplacesRequestedRevocation() async {
    for kind in [AuthRevocationKind.signOut, .withdrawal] {
      let storage = MemorySecureStorage()
      let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
      let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
      #expect(await auth.prepareRevocation(kind, ifSessionIDMatches: await auth.sessionID))
      let concurrentID = await auth.stageSession(accessToken: "early", refreshToken: "early-refresh")
      #expect(await auth.commitSession(concurrentID) == false)

      let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      #expect(await restarted.isLoggedIn == false)
      #expect(await restarted.refreshToken == nil)
      let id = await restarted.stageSession(accessToken: "new-access", refreshToken: "new-refresh")
      #expect(await restarted.commitSession(id))
      #expect(await restarted.isLoggedIn)
      #expect(await restarted.refreshToken == "new-refresh")
      #expect(storage.load(.refreshToken) == "new-refresh")
      #expect(FileManager.default.fileExists(atPath: storage.journalURL.path) == false)

      let secondRestart = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
      #expect(await secondRestart.refreshToken == "new-refresh")
    }
  }

  @Test("전송 결과가 불명확한 요청이 끝난 뒤 새 로그인은 기존 요청 기록을 대체한다")
  func newLoginAfterUncertainRequest() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: old.accessToken, refreshToken: old.refreshToken)
    #expect(await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: await auth.sessionID))
    let id = await auth.stageSession(accessToken: "new-access", refreshToken: "new-refresh")
    #expect(await auth.commitSession(id) == false)

    await auth.finishRevocationRequest()
    #expect(await auth.commitSession(id))
    #expect(await auth.refreshToken == "new-refresh")
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path) == false)
  }

  @Test("읽기 불가 상태가 사라지면 기존 인증 객체도 저장된 세션을 다시 확인한다")
  func temporaryJournalReadFailureRecovers() async throws {
    let storage = MemorySecureStorage()
    #expect(KeychainCredentialStore(storage: storage).save(old))
    try FileManager.default.createDirectory(at: storage.journalURL, withIntermediateDirectories: true)
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await auth.isLoggedIn == false)

    try FileManager.default.removeItem(at: storage.journalURL)
    #expect(await auth.isLoggedIn)
    #expect(await auth.refreshToken == old.refreshToken)
  }

  @Test("로그아웃 및 재로그인 뒤에는 이전 토큰 갱신 결과를 교체하지 않는다")
  func guardedStoreRejectsPreviousSessionRefresh() throws {
    let storage = MemorySecureStorage()
    let guarded = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    let late = FestiCoreCredential(accessToken: "late", refreshToken: "late-refresh")
    guarded.allowSaves()
    guarded.save(old)
    let oldRevision = try #require(guarded.revision(matching: old))

    guarded.clear()
    #expect(try guarded.replace(late, ifCurrent: old, revision: oldRevision) == false)
    #expect(guarded.load() == nil)

    let replacement = FestiCoreCredential(accessToken: "signed-in", refreshToken: "other-refresh")
    guarded.allowSaves()
    guarded.save(replacement)
    #expect(try guarded.replace(late, ifCurrent: old, revision: oldRevision) == false)
    #expect(guarded.load() == replacement)
    #expect(storage.load(.accessToken) == "signed-in")

    guarded.clear()
    guarded.allowSaves()
    guarded.save(old)
    #expect(try guarded.replace(late, ifCurrent: old, revision: oldRevision) == false)
    #expect(guarded.load() == old)
  }

  @Test("키체인에서 다시 읽은 JWT 만료시각은 갱신 세션 비교와 일치한다")
  func keychainReloadPreservesRefreshIdentity() throws {
    let storage = MemorySecureStorage()
    let store = KeychainCredentialStore(storage: storage)
    let token = "eyJhbGciOiJub25lIn0.eyJleHAiOjE4MDAwMDAwMDB9.signature"
    let current = FestiCoreCredential(
      accessToken: token,
      refreshToken: "refresh",
      expiresAt: JWTDecoder.decodeExpiration(token)
    )
    let renewed = FestiCoreCredential(accessToken: "renewed", refreshToken: "new-refresh")
    store.save(current)

    #expect(store.load() == current)
    let revision = try #require(store.revision(matching: current))
    #expect(try store.replace(renewed, ifCurrent: current, revision: revision))
    #expect(store.load() == renewed)
  }

  @Test("토큰 쌍 저장이 실패하면 로그인을 확정하지 않고 부분 저장을 지운다", arguments: [SecureStorageKey.credentialIntegrity, .accessToken, .refreshToken])
  func failedTokenSaveDoesNotCommitSession(failedKey: SecureStorageKey) async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    storage.failTokenSaveFor = failedKey

    let id = await auth.stageSession(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    #expect(await auth.commitSession(id) == false)
    #expect(await auth.isLoggedIn == false)
    #expect(storage.load(.accessToken) == nil)
    #expect(storage.load(.refreshToken) == nil)

    storage.failTokenSaveFor = nil
    let retry = await auth.stageSession(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    #expect(await auth.commitSession(retry))
    #expect(await auth.isLoggedIn)
  }

  @Test("토큰 갱신 저장이 실패하면 영속화 오류를 던진다")
  func failedTokenSaveRejectsRefreshReplacement() throws {
    let storage = MemorySecureStorage()
    let store = KeychainCredentialStore(storage: storage)
    #expect(store.save(old))
    let revision = try #require(store.revision(matching: old))
    storage.failTokenSaveFor = .refreshToken

    #expect(throws: CredentialStoreError.self) { try store.replace(
      FestiCoreCredential(accessToken: "new", refreshToken: "new-refresh"),
      ifCurrent: old,
      revision: revision
    ) }
    #expect(store.load() == nil)
    #expect(storage.load(.accessToken) == nil)
    #expect(storage.load(.refreshToken) == nil)
  }

  @Test("무결성 값 첫 쓰기가 실패해도 이전 세션을 다시 읽지 않는다")
  func failedIntegrityPrewriteCannotRestoreOldSession() throws {
    let storage = MemorySecureStorage()
    let store = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    store.allowSaves()
    #expect(store.save(old))
    let revision = try #require(store.revision(matching: old))
    storage.failTokenSaveFor = .credentialIntegrity

    #expect(throws: CredentialStoreError.self) { try store.replace(
      FestiCoreCredential(accessToken: "new", refreshToken: "new-refresh"),
      ifCurrent: old,
      revision: revision
    ) }
    #expect(store.load() == nil)
    #expect(KeychainCredentialStore(storage: storage).load() == nil)
    #expect(storage.load(.accessToken) == nil)
    #expect(storage.load(.refreshToken) == nil)
  }

  @Test("무결성 값 최종 쓰기가 실패해도 토큰 쌍을 복원하지 않는다")
  func failedFinalIntegrityWriteCannotRestoreMixedSession() throws {
    let storage = MemorySecureStorage()
    let store = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    store.allowSaves()
    #expect(store.save(old))
    let revision = try #require(store.revision(matching: old))
    storage.failIntegritySaveAtAttempt = 2

    #expect(throws: CredentialStoreError.self) { try store.replace(
      FestiCoreCredential(accessToken: "new", refreshToken: "new-refresh"),
      ifCurrent: old,
      revision: revision
    ) }
    #expect(KeychainCredentialStore(storage: storage).load() == nil)
  }

  @Test("기존 설치의 검증 값 없는 토큰 쌍을 읽는다")
  func legacyCredentialWithoutIntegrityLoads() throws {
    let storage = MemorySecureStorage()
    try storage.save(old.accessToken, for: .accessToken)
    try storage.save(old.refreshToken, for: .refreshToken)

    #expect(KeychainCredentialStore(storage: storage).load() == old)
  }

  @Test("롤백 삭제가 실패해도 혼합 토큰 쌍을 재실행에서 복원하지 않는다")
  func failedRollbackCannotRestoreMixedTokens() throws {
    let storage = MemorySecureStorage()
    let store = KeychainCredentialStore(storage: storage)
    #expect(store.save(old))
    let revision = try #require(store.revision(matching: old))
    storage.failTokenSaveFor = .refreshToken
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]

    #expect(throws: CredentialStoreError.self) { try store.replace(
      FestiCoreCredential(accessToken: "new", refreshToken: "new-refresh"),
      ifCurrent: old,
      revision: revision
    ) }
    #expect(storage.load(.accessToken) == "new")
    #expect(storage.load(.refreshToken) == "old-refresh")
    #expect(store.load() == nil)
    #expect(KeychainCredentialStore(storage: storage).load() == nil)
  }

  @Test("갱신 저장 실패는 공유 인증 세션 제거를 알린다")
  func failedRefreshSaveInvokesPersistenceHandler() throws {
    let storage = MemorySecureStorage()
    let store = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    store.allowSaves()
    #expect(store.save(old))
    let revision = try #require(store.revision(matching: old))
    let failures = OSAllocatedUnfairLock(initialState: 0)
    store.setPersistenceFailureHandler { failures.withLock { $0 += 1 } }
    storage.failTokenSaveFor = .refreshToken

    #expect(throws: CredentialStoreError.self) { try store.replace(
      FestiCoreCredential(accessToken: "new", refreshToken: "new-refresh"),
      ifCurrent: old,
      revision: revision
    ) }
    #expect(failures.withLock { $0 } == 1)
    #expect(store.load() == nil)
  }

  @Test("로그인 응답은 확정 전까지 Keychain과 로그인 상태를 바꾸지 않는다")
  func stagedSessionIsNotPersistedUntilCommit() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)

    let id = await auth.stageSession(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")
    #expect(await auth.isLoggedIn == false)
    #expect(storage.load(.accessToken) == nil)
    #expect(await auth.commitSession(UUID()) == false)

    #expect(await auth.commitSession(id))
    #expect(await auth.isLoggedIn)
    #expect(storage.load(.refreshToken) == "refresh-a")
    #expect(await auth.currentUserID == "user-a")
    #expect(await auth.commitSession(id) == false)
  }

  @Test("폐기는 같은 임시 세션만 지우고 확정 세션과 새 임시 세션은 남긴다")
  func discardOnlyRemovesMatchingStagedSession() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")

    let stale = await auth.stageSession(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")
    let fresh = await auth.stageSession(accessToken: jwt(subject: "user-c"), refreshToken: "refresh-c")
    #expect(await auth.discardSession(stale) == false)
    #expect(await auth.commitSession(stale) == false)
    #expect(storage.load(.refreshToken) == "refresh-a")
    #expect(await auth.currentUserID == "user-a")

    #expect(await auth.discardSession(fresh))
    #expect(await auth.commitSession(fresh) == false)
    #expect(await auth.isLoggedIn)
    #expect(storage.load(.refreshToken) == "refresh-a")
  }

  @Test("확정 세션이 있어도 새 임시 세션의 계정 ID를 그 토큰으로 검증해 확정 때 저장한다")
  func stagedSessionRemembersItsOwnUserID() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")

    let id = await auth.stageSession(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")
    await auth.rememberUserID("user-a")
    await auth.rememberUserID("user-b")
    #expect(await auth.currentUserID == "user-a")

    #expect(await auth.commitSession(id))
    #expect(await auth.currentUserID == "user-b")
  }

  @Test("로그아웃은 임시 세션도 비운다")
  func signOutDropsStagedSession() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let id = await auth.stageSession(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")

    await auth.signOut()
    #expect(await auth.commitSession(id) == false)
    #expect(await auth.isLoggedIn == false)
  }

  @Test("닫힌 로그인의 확정 세션은 그 식별자일 때만 되돌리고 진행 중인 임시 세션은 남긴다")
  func conditionalSignOutOnlyRevokesMatchingCommittedSession() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let first = await auth.stageSession(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    #expect(await auth.commitSession(first))
    let next = await auth.stageSession(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")

    #expect(await auth.signOut(ifSession: UUID()) == false)
    #expect(await auth.isLoggedIn)
    #expect(await auth.signOut(ifSession: first))
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.signOut(ifSession: first) == false)
    #expect(await auth.commitSession(next))
    #expect(storage.load(.refreshToken) == "refresh-b")
  }

  @Test("기존 세션의 자동 만료는 진행 중인 새 로그인의 임시 세션을 지우지 않는다")
  func authFailureKeepsStagedSession() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let made = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let auth = try #require(made as? FestiCoreAuth)
    await signIn(auth, accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    let next = await auth.stageSession(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")

    let oldSessionID = await auth.sessionID
    await auth.handleAuthFailure(
      for: FestiCoreCredential(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a"),
      sessionID: oldSessionID
    )
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.commitSession(next))
    #expect(storage.load(.refreshToken) == "refresh-b")
  }

  @Test("인증 만료 중 Keychain 삭제가 실패해도 재시작 뒤 이전 토큰을 복원하지 않는다")
  func authFailureClearFailureBlocksRestoration() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let made = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let auth = try #require(made as? FestiCoreAuth)
    let accessToken = jwt(subject: "user-a")
    await signIn(auth, accessToken: accessToken, refreshToken: "refresh-a")
    let sessionID = await auth.sessionID
    storage.failTokenSaveFor = .credentialIntegrity
    storage.failTokenRemovalFor = [.accessToken, .refreshToken]

    await auth.handleAuthFailure(
      for: FestiCoreCredential(accessToken: accessToken, refreshToken: "refresh-a"),
      sessionID: sessionID
    )

    #expect(await auth.hasPendingLocalClear)
    #expect(storage.load(.refreshToken) == "refresh-a")
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path))
    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.isLoggedIn == false)
    #expect(await restarted.refreshToken == nil)
    #expect(await restarted.hasPendingLocalClear)
    storage.failTokenSaveFor = nil
    storage.failTokenRemovalFor = []
    #expect(await restarted.signOut())
    #expect(FileManager.default.fileExists(atPath: storage.journalURL.path) == false)
  }

  @Test("탈퇴 요청 중 인증 만료는 미확정 서버 결과 기록을 유지한다")
  func authFailureDuringWithdrawalPreservesRequestJournal() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let made = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    let auth = try #require(made as? FestiCoreAuth)
    let accessToken = jwt(subject: "user-a")
    let stagedSessionID = await auth.stageSession(accessToken: accessToken, refreshToken: "refresh-a")
    #expect(await auth.commitSession(stagedSessionID))
    let sessionID = await auth.sessionID
    #expect(await auth.authenticatedSessionID == sessionID)
    #expect(await auth.isLoggedIn)
    let journal = SessionRevocationJournal(url: storage.journalURL)
    let journalBefore = String(describing: journal.status)
    let sessionBefore = await auth.authenticatedSessionID
    let prepared = await auth.prepareRevocation(.withdrawal, ifSessionIDMatches: sessionID)
    let journalAfter = String(describing: journal.status)
    let preparationDiagnostics = await auth.revocationPreparationDiagnostics
    if !prepared {
      Issue.record("준비 진단: \(preparationDiagnostics)")
      let directRecord = journal.record(.withdrawalRequested)
      let sessionAfter = await auth.authenticatedSessionID
      Issue.record(
        "직접 저널 기록: \(directRecord), 상태: \(String(describing: journal.status)), 세션 후: \(String(describing: sessionAfter))"
      )
      if !directRecord {
        do {
          try Data("withdrawalRequested".utf8).write(to: storage.journalURL, options: .atomic)
          Issue.record("정확한 저널 경로 쓰기 성공: \(String(describing: journal.status))")
        } catch {
          let error = error as NSError
          Issue.record("정확한 저널 경로 쓰기 실패: \(error.domain) \(error.code) \(error.localizedDescription)")
        }
      }
      let probeURL = storage.journalURL.deletingLastPathComponent().appendingPathComponent("write-probe")
      do {
        try FileManager.default.createDirectory(at: probeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("probe".utf8).write(to: probeURL, options: .atomic)
        let readback = try Data(contentsOf: probeURL)
        Issue.record("저널 디렉터리 쓰기 성공: \(String(decoding: readback, as: UTF8.self))")
        try? FileManager.default.removeItem(at: probeURL)
      } catch {
        Issue.record("저널 디렉터리 쓰기 실패: \(error)")
      }
    }
    #expect(
      prepared,
      "저널 이전: \(journalBefore), 이후: \(journalAfter), 세션: \(String(describing: sessionBefore))"
    )

    await auth.handleAuthFailure(
      for: FestiCoreCredential(accessToken: accessToken, refreshToken: "refresh-a"),
      sessionID: sessionID
    )

    let restarted = AuthFactory.make(refreshClient: client, storage: storage, revocationJournalURL: storage.journalURL)
    #expect(await restarted.hasUnconfirmedRevocation)
    #expect(await restarted.isLoggedIn == false)
  }

  @Test("이전 세션의 갱신 401은 같은 토큰으로 다시 로그인한 세션을 종료하지 않는다")
  func staleRefreshFailureKeepsSameTokenRelogin() async throws {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let made = AuthFactory.make(refreshClient: client, storage: storage)
    let auth = try #require(made as? FestiCoreAuth)
    let accessToken = jwt(subject: "user-a")
    let refreshToken = "shared-refresh"
    await signIn(auth, accessToken: accessToken, refreshToken: refreshToken)
    let oldSessionID = await auth.sessionID

    let oldCredential = FestiCoreCredential(accessToken: accessToken, refreshToken: refreshToken)
    let refreshClient = StubRefreshClient(
      result: .failure(.response(ResponseError(httpStatus: 401))),
      beforeResponse: { await signIn(auth, accessToken: accessToken, refreshToken: refreshToken) }
    )
    let refresher = TokenRefresher(client: refreshClient) {
      credential, sessionID in
      await auth.handleAuthFailure(for: credential, sessionID: sessionID)
    }

    do {
      _ = try await refresher.refresh(oldCredential, sessionID: oldSessionID)
      Issue.record("이전 세션의 갱신은 401로 실패해야 한다")
    } catch {
      guard case let FestiCoreNetworkError.response(response) = error else {
        Issue.record("응답 오류 기대: \(error)")
        return
      }
      #expect(response.httpStatus == 401)
    }

    let newSessionID = await auth.sessionID
    #expect(newSessionID != oldSessionID)
    #expect(await auth.isLoggedIn)
    #expect(await auth.sessionID == newSessionID)
    #expect(storage.load(.refreshToken) == refreshToken)
  }

  @Test("팩토리의 갱신 401도 같은 토큰으로 재로그인한 세션을 유지한다")
  func factoryRefreshFailureKeepsSameTokenRelogin() async throws {
    let storage = MemorySecureStorage()
    let holder = AuthHolder()
    let accessToken = jwt(subject: "user-a", expiresAt: 1)
    let refreshToken = "shared-refresh"
    let refreshClient = StubRefreshClient(
      result: .failure(.response(ResponseError(httpStatus: 401))),
      beforeResponse: {
        await holder.relogin(accessToken: accessToken, refreshToken: refreshToken)
      }
    )
    let auth = AuthFactory.make(
      refreshClient: refreshClient,
      storage: storage,
      baseURL: URL(string: "https://festicore.test")
    )
    await holder.set(auth)
    await signIn(auth, accessToken: accessToken, refreshToken: refreshToken)
    let oldSessionID = await auth.sessionID

    do {
      _ = try await auth.authenticatedClient.sendResponse(AuthRequest.me(sessionID: oldSessionID))
      Issue.record("이전 세션의 갱신은 실패해야 한다")
    } catch {}

    #expect(refreshClient.lastRequest?.path == "api/v1/auth/refresh")
    #expect(await auth.sessionID != oldSessionID)
    #expect(await auth.isLoggedIn)
    #expect(storage.load(.refreshToken) == refreshToken)
  }
}

private actor AuthHolder {
  private var auth: (any AuthService)?

  func set(_ auth: any AuthService) { self.auth = auth }

  func relogin(accessToken: String, refreshToken: String) async {
    guard let auth else { return }
    let id = await auth.stageSession(accessToken: accessToken, refreshToken: refreshToken)
    _ = await auth.commitSession(id)
  }
}

private actor FailureRecorder {
  private(set) var count = 0
  func record() { count += 1 }
}

private final class MemorySecureStorage: SecureStorage, @unchecked Sendable {
  let journalURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("festicore-auth-\(UUID())/session-revocation")
  deinit { try? FileManager.default.removeItem(at: journalURL.deletingLastPathComponent()) }
  private let values = NSLock()
  private var stored: [SecureStorageKey: String] = [:]
  private var failsIdentityRemoval = false
  private var failsIdentitySave = false
  private var tokenSaveFailureKey: SecureStorageKey?
  private var integritySaveFailureAttempt: Int?
  private var integritySaveAttempts = 0
  private var tokenRemovalFailureKeys: Set<SecureStorageKey> = []

  var failIdentityRemoval: Bool {
    get { values.withLock { failsIdentityRemoval } }
    set { values.withLock { failsIdentityRemoval = newValue } }
  }

  var failIdentitySave: Bool {
    get { values.withLock { failsIdentitySave } }
    set { values.withLock { failsIdentitySave = newValue } }
  }

  var failTokenSaveFor: SecureStorageKey? {
    get { values.withLock { tokenSaveFailureKey } }
    set { values.withLock { tokenSaveFailureKey = newValue } }
  }

  var failIntegritySaveAtAttempt: Int? {
    get { values.withLock { integritySaveFailureAttempt } }
    set {
      values.withLock {
        integritySaveFailureAttempt = newValue
        integritySaveAttempts = 0
      }
    }
  }

  var failTokenRemovalFor: Set<SecureStorageKey> {
    get { values.withLock { tokenRemovalFailureKeys } }
    set { values.withLock { tokenRemovalFailureKeys = newValue } }
  }

  func save(_ value: String, for key: SecureStorageKey) throws(SecureStorageError) {
    let failed = values.withLock {
      if key == .sessionUserID, failsIdentitySave { return true }
      if let tokenSaveFailureKey, key == tokenSaveFailureKey { return true }
      if key == .credentialIntegrity {
        integritySaveAttempts += 1
        if let integritySaveFailureAttempt,
           integritySaveAttempts == integritySaveFailureAttempt { return true }
      }
      stored[key] = value
      return false
    }
    if failed { throw .invalidData }
  }
  func load(_ key: SecureStorageKey) -> String? { values.withLock { stored[key] } }
  func remove(_ key: SecureStorageKey) throws(SecureStorageError) {
    let failed = values.withLock {
      if key == .sessionUserID, failsIdentityRemoval { return true }
      if tokenRemovalFailureKeys.contains(key) { return true }
      stored.removeValue(forKey: key)
      return false
    }
    if failed { throw .invalidData }
  }
  func removeAll() { values.withLock { stored.removeAll() } }
}

private func jwt(subject: String, suffix: String = "signature", expiresAt: Int? = nil) -> String {
  let expiration = expiresAt.map { ",\"exp\":\($0)" } ?? ""
  let payload = Data("{\"sub\":\"\(subject)\"\(expiration)}".utf8).base64EncodedString()
  return "header.\(payload).\(suffix)"
}

private final class StubRefreshClient: FestiCoreRequestClient, @unchecked Sendable {
  struct CapturedRequest: Sendable {
    let path: String
    let authorization: FestiCoreAuthorization
    let refreshToken: String?
  }

  private let result: Result<Data, FestiCoreNetworkError>
  private let beforeResponse: (@Sendable () async -> Void)?
  private let lock = NSLock()
  private var captured: CapturedRequest?

  init(
    result: Result<Data, FestiCoreNetworkError>,
    beforeResponse: (@Sendable () async -> Void)? = nil
  ) {
    self.result = result
    self.beforeResponse = beforeResponse
  }

  var lastRequest: CapturedRequest? { lock.withLock { captured } }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let parameters = request.parameters
    let body = parameters.flatMap { try? JSONEncoder().encode($0) }
    let refreshToken = body.flatMap {
      (try? JSONSerialization.jsonObject(with: $0) as? [String: String])?["refreshToken"]
    }
    lock.withLock {
      captured = CapturedRequest(
        path: request.path,
        authorization: request.authorization,
        refreshToken: refreshToken
      )
    }
    await beforeResponse?()
    let data: Data
    switch result {
    case let .success(value): data = value
    case let .failure(error): throw error
    }
    do { return try JSONDecoder().decode(T.self, from: data) }
    catch { throw .decoding(.failed(error)) }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    Issue.record("인증 요청은 응답 타입을 지정해 전송해야 한다")
    throw .request(.invalidURL)
  }

  func sendResponse<R: FestiCoreDataRequest>(_: R) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}

/// 실제 로그인처럼 임시 세션을 만든 뒤 바로 확정한다.
private func signIn(_ auth: some AuthService, accessToken: String, refreshToken: String) async {
  let id = await auth.stageSession(accessToken: accessToken, refreshToken: refreshToken)
  _ = await auth.commitSession(id)
}
