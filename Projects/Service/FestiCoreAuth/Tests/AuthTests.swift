//
//  AuthTests.swift
//  FestiCoreAuthTests
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import Testing
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
    let refresher = TokenRefresher(client: client) { _ in await recorder.record() }

    let renewed = try await refresher.refresh(old)

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
    let refresher = TokenRefresher(client: client) { _ in await recorder.record() }

    do {
      _ = try await refresher.refresh(old)
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
    let refresher = TokenRefresher(client: client) { _ in await recorder.record() }

    do {
      _ = try await refresher.refresh(old)
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
      baseURL: URL(string: "https://festicore.test")
    )
    let client = auth.authenticatedClient
    #expect((client as AnyObject) === (auth.authenticatedClient as AnyObject))

    await auth.signIn(accessToken: jwt(subject: "user-a"), refreshToken: "old-refresh")
    await auth.rememberUserID("user-a")
    #expect(await auth.currentUserID == "user-a")
    #expect(storage.load(.accessToken) == jwt(subject: "user-a"))
    #expect(storage.load(.refreshToken) == "old-refresh")

    let restored = AuthFactory.make(refreshClient: refreshClient, storage: storage)
    #expect(await restored.currentUserID == "user-a")

    await auth.signIn(accessToken: jwt(subject: "user-b"), refreshToken: "new-refresh")
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
    let auth = AuthFactory.make(refreshClient: client, storage: storage)

    await auth.signIn(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")
    #expect(await auth.currentUserID == "user-a")

    storage.failIdentityRemoval = true
    storage.failIdentitySave = true
    await auth.signIn(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")
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
    let auth = AuthFactory.make(refreshClient: client, storage: storage)
    let oldToken = jwt(subject: "user-a")
    let newToken = jwt(subject: "user-a", suffix: "renewed")
    await auth.signIn(accessToken: oldToken, refreshToken: "refresh-a")
    await auth.rememberUserID("user-a")
    let sessionID = await auth.sessionID

    let credentialStore = KeychainCredentialStore(storage: storage)
    let oldCredential = try #require(credentialStore.load())
    let revision = try #require(credentialStore.revision(matching: oldCredential))
    #expect(credentialStore.replace(
      FestiCoreCredential(accessToken: newToken, refreshToken: "refresh-a-rotated"),
      ifCurrent: oldCredential,
      revision: revision
    ))
    #expect(await auth.currentUserID == "user-a")
    #expect(await auth.sessionID == sessionID)
    let restored = AuthFactory.make(refreshClient: client, storage: storage)
    #expect(await restored.currentUserID == "user-a")
  }

  @Test("이전 로그인 식별자로 새 세션을 지울 수 없다")
  func staleSessionCannotSignOutNewLogin() async {
    let storage = MemorySecureStorage()
    let client = NetworkClientFactory.plain(baseURL: URL(string: "https://festicore.test"))
    let auth = AuthFactory.make(refreshClient: client, storage: storage)
    await auth.signIn(accessToken: jwt(subject: "user-a"), refreshToken: "refresh-a")
    let oldSessionID = await auth.sessionID

    await auth.signIn(accessToken: jwt(subject: "user-b"), refreshToken: "refresh-b")
    #expect(await auth.signOut(ifSessionIDMatches: oldSessionID) == false)
    #expect(await auth.isLoggedIn)
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

  @Test("로그아웃 및 재로그인 뒤에는 이전 토큰 갱신 결과를 교체하지 않는다")
  func guardedStoreRejectsPreviousSessionRefresh() throws {
    let storage = MemorySecureStorage()
    let guarded = GuardedCredentialStore(base: KeychainCredentialStore(storage: storage))
    let late = FestiCoreCredential(accessToken: "late", refreshToken: "late-refresh")
    guarded.allowSaves()
    guarded.save(old)
    let oldRevision = try #require(guarded.revision(matching: old))

    guarded.clear()
    #expect(guarded.replace(late, ifCurrent: old, revision: oldRevision) == false)
    #expect(guarded.load() == nil)

    let replacement = FestiCoreCredential(accessToken: "signed-in", refreshToken: "other-refresh")
    guarded.allowSaves()
    guarded.save(replacement)
    #expect(guarded.replace(late, ifCurrent: old, revision: oldRevision) == false)
    #expect(guarded.load() == replacement)
    #expect(storage.load(.accessToken) == "signed-in")

    guarded.clear()
    guarded.allowSaves()
    guarded.save(old)
    #expect(guarded.replace(late, ifCurrent: old, revision: oldRevision) == false)
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
    #expect(store.replace(renewed, ifCurrent: current, revision: revision))
    #expect(store.load() == renewed)
  }
}

private actor FailureRecorder {
  private(set) var count = 0
  func record() { count += 1 }
}

private final class MemorySecureStorage: SecureStorage, @unchecked Sendable {
  private let values = NSLock()
  private var stored: [SecureStorageKey: String] = [:]
  private var failsIdentityRemoval = false
  private var failsIdentitySave = false

  var failIdentityRemoval: Bool {
    get { values.withLock { failsIdentityRemoval } }
    set { values.withLock { failsIdentityRemoval = newValue } }
  }

  var failIdentitySave: Bool {
    get { values.withLock { failsIdentitySave } }
    set { values.withLock { failsIdentitySave = newValue } }
  }

  func save(_ value: String, for key: SecureStorageKey) throws(SecureStorageError) {
    let failed = values.withLock {
      if key == .sessionUserID, failsIdentitySave { return true }
      stored[key] = value
      return false
    }
    if failed { throw .invalidData }
  }
  func load(_ key: SecureStorageKey) -> String? { values.withLock { stored[key] } }
  func remove(_ key: SecureStorageKey) throws(SecureStorageError) {
    let failed = values.withLock {
      if key == .sessionUserID, failsIdentityRemoval { return true }
      stored.removeValue(forKey: key)
      return false
    }
    if failed { throw .invalidData }
  }
  func removeAll() { values.withLock { stored.removeAll() } }
}

private func jwt(subject: String, suffix: String = "signature") -> String {
  let payload = Data("{\"sub\":\"\(subject)\"}".utf8).base64EncodedString()
  return "header.\(payload).\(suffix)"
}

private final class StubRefreshClient: FestiCoreRequestClient, @unchecked Sendable {
  struct CapturedRequest: Sendable {
    let path: String
    let authorization: FestiCoreAuthorization
    let refreshToken: String?
  }

  private let result: Result<Data, FestiCoreNetworkError>
  private let lock = NSLock()
  private var captured: CapturedRequest?

  init(result: Result<Data, FestiCoreNetworkError>) { self.result = result }

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
