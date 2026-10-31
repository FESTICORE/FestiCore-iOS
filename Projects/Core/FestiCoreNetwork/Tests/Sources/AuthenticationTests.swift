//
//  AuthenticationTests.swift
//  FestiCoreNetworkTests
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation
import Testing

@testable import FestiCoreNetwork
import FestiCoreNetworkInterface

import Alamofire

@Suite("FestiCore 인증 파이프라인")
struct AuthenticationTests {
  private let current = FestiCoreCredential(accessToken: "old-access", refreshToken: "refresh")
  private let renewed = FestiCoreCredential(accessToken: "new-access", refreshToken: "new-refresh")

  @Test("Authenticator는 Bearer 토큰을 적용하고 인증된 요청을 판별한다")
  func appliesAndRecognizesCredential() {
    let authenticator = FestiCoreAuthenticator(
      refresher: StubTokenRefresher(result: .success(renewed)),
      store: RecordingCredentialStore()
    )
    var request = URLRequest(url: URL(string: "https://festicore.test/private")!)

    authenticator.apply(current, to: &request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access")
    #expect(authenticator.isRequest(request, authenticatedWith: current))
    #expect(authenticator.isRequest(request, authenticatedWith: renewed) == false)
  }

  @Test("401만 인증 실패로 판별한다")
  func detectsAuthenticationFailure() {
    let authenticator = FestiCoreAuthenticator(
      refresher: StubTokenRefresher(result: .success(renewed)),
      store: RecordingCredentialStore()
    )
    let request = URLRequest(url: URL(string: "https://festicore.test/private")!)
    let unauthorized = HTTPURLResponse(
      url: request.url!,
      statusCode: 401,
      httpVersion: nil,
      headerFields: nil
    )!
    let forbidden = HTTPURLResponse(
      url: request.url!,
      statusCode: 403,
      httpVersion: nil,
      headerFields: nil
    )!

    #expect(
      authenticator.didRequest(
        request,
        with: unauthorized,
        failDueToAuthenticationError: URLError(.userAuthenticationRequired)
      )
    )
    #expect(
      authenticator.didRequest(
        request,
        with: forbidden,
        failDueToAuthenticationError: URLError(.userAuthenticationRequired)
      ) == false
    )
  }

  @Test("토큰 갱신 성공 결과를 저장하고 호출자에게 돌려준다")
  func refreshPersistsCredential() async throws {
    let store = RecordingCredentialStore(initial: current)
    let authenticator = FestiCoreAuthenticator(
      refresher: StubTokenRefresher(result: .success(renewed)),
      store: store
    )

    let result = try await refresh(authenticator, credential: current)

    #expect(result == renewed)
    #expect(store.saved == renewed)
  }

  @Test("토큰 갱신 실패를 그대로 전달하고 저장하지 않는다")
  func refreshPropagatesFailure() async {
    let store = RecordingCredentialStore(initial: current)
    let expected = ResponseError(httpStatus: 401, code: "REFRESH_EXPIRED")
    let authenticator = FestiCoreAuthenticator(
      refresher: StubTokenRefresher(result: .failure(.response(expected))),
      store: store
    )

    do {
      _ = try await refresh(authenticator, credential: current)
      Issue.record("갱신 실패가 전달되어야 한다")
    } catch {
      guard case let FestiCoreNetworkError.response(error) = error else {
        Issue.record("response 에러 기대, got \(error)")
        return
      }
      #expect(error == expected)
      #expect(store.saved == current)
    }
  }

  @Test("로그아웃 중 완료된 갱신은 인터셉터에 credential을 복원하지 않는다")
  func refreshAfterSignOutCannotRestoreInterceptor() async throws {
    let expiring = FestiCoreCredential(
      accessToken: "old-access",
      refreshToken: "refresh",
      expiresAt: .distantPast
    )
    let store = RecordingCredentialStore(initial: expiring)
    let refresher = SuspendedTokenRefresher()
    let (authorizing, updater) = SessionFactory.authorization(store: store, refresher: refresher)
    let request = URLRequest(url: URL(string: "https://festicore.test/private")!)
    let adaptation = Task { try await adapt(authorizing, request: request) }

    await refresher.waitUntilStarted()
    store.clear()
    updater.update(nil)
    await refresher.complete(with: renewed)

    do {
      _ = try await adaptation.value
      Issue.record("로그아웃한 세션의 갱신은 실패해야 한다")
    } catch {
      #expect(store.load() == nil)
      #expect(authorizing.base.credential == nil)
    }
  }

  @Test("새 로그인 중 완료된 이전 세션 갱신은 새 credential을 보존한다")
  func refreshAfterReplacementSignInCannotOverwrite() async throws {
    let store = RecordingCredentialStore(initial: current)
    let refresher = SuspendedTokenRefresher()
    let authenticator = FestiCoreAuthenticator(refresher: refresher, store: store)
    let operation = Task { try await refresh(authenticator, credential: current) }

    await refresher.waitUntilStarted()
    let replacement = FestiCoreCredential(accessToken: "signed-in", refreshToken: "other-refresh")
    store.save(replacement)
    await refresher.complete(with: renewed)

    do {
      _ = try await operation.value
      Issue.record("이전 세션의 갱신은 실패해야 한다")
    } catch {
      #expect(store.load() == replacement)
    }
  }

  @Test("동일 토큰 재로그인도 이전 갱신 세션과 구별한다")
  func refreshAfterSameTokenSignInIsRejected() async throws {
    let store = RecordingCredentialStore(initial: current)
    let refresher = SuspendedTokenRefresher()
    let authenticator = FestiCoreAuthenticator(refresher: refresher, store: store)
    let operation = Task { try await refresh(authenticator, credential: current) }

    await refresher.waitUntilStarted()
    store.save(current)
    await refresher.complete(with: renewed)

    do {
      _ = try await operation.value
      Issue.record("동일 토큰이어도 새 로그인 후 이전 갱신은 실패해야 한다")
    } catch {
      #expect(store.load() == current)
    }
  }

  @Test("갱신 작업 예약 전에 같은 토큰으로 재로그인해도 이전 세션 ID를 전달한다")
  func refreshCapturesSessionBeforeScheduling() async throws {
    let store = RecordingCredentialStore(initial: current)
    let oldSessionID = try #require(store.sessionSnapshot()?.id)
    store.reloginAfterNextRefreshContext()
    let refresher = ContextCapturingRefresher()
    let authenticator = FestiCoreAuthenticator(refresher: refresher, store: store)

    do {
      _ = try await refresh(authenticator, credential: current)
      Issue.record("이전 세션의 갱신은 실패해야 한다")
    } catch {
      #expect(store.sessionSnapshot()?.id != oldSessionID)
      #expect(store.load() == current)
      #expect(await refresher.capturedSessionID == oldSessionID)
    }
  }

  @Test("credential이 없으면 AuthorizingInterceptor가 요청을 변경하지 않는다")
  func authorizingBypassesMissingCredential() async throws {
    let store = RecordingCredentialStore()
    let (authorizing, _) = SessionFactory.authorization(
      store: store,
      refresher: StubTokenRefresher(result: .success(renewed))
    )
    let request = URLRequest(url: URL(string: "https://festicore.test/public")!)

    let adapted = try await adapt(authorizing, request: request)

    #expect(adapted.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test("credential이 있으면 AuthorizingInterceptor가 토큰을 적용한다")
  func authorizingApCredential() async throws {
    let store = RecordingCredentialStore(initial: current)
    let (authorizing, _) = SessionFactory.authorization(
      store: store,
      refresher: StubTokenRefresher(result: .success(renewed))
    )
    let request = URLRequest(url: URL(string: "https://festicore.test/private")!)

    let adapted = try await adapt(authorizing, request: request)

    #expect(adapted.value(forHTTPHeaderField: "Authorization") == "Bearer old-access")
  }

  @Test("세션 지정 요청은 다른 로그인 토큰으로 적응하지 않는다")
  func boundRequestRejectsNewSessionDuringAdapt() async throws {
    let expiring = FestiCoreCredential(
      accessToken: "old-access", refreshToken: "refresh", expiresAt: .distantPast
    )
    let store = RecordingCredentialStore(initial: expiring)
    let expected = try #require(store.sessionSnapshot()?.id)
    let refresher = SuspendedTokenRefresher()
    let (authorizing, updater) = SessionFactory.authorization(store: store, refresher: refresher)
    let request = URLRequest(url: URL(string: "https://festicore.test/private")!)
    let adaptation = Task { try await adapt(authorizing.bound(to: expected), request: request) }

    await refresher.waitUntilStarted()
    let replacement = FestiCoreCredential(accessToken: "account-b", refreshToken: "refresh-b")
    store.save(replacement)
    updater.update(replacement)
    await refresher.complete(with: renewed)

    do {
      _ = try await adaptation.value
      Issue.record("이전 세션의 요청은 적응에 실패해야 한다")
    } catch {
      #expect(store.sessionSnapshot()?.credential == replacement)
    }
  }

  @Test("세션 지정 요청은 계정 전환 후 재시도하지 않는다")
  func boundRequestDoesNotRetryNewSession() async throws {
    let store = RecordingCredentialStore(initial: current)
    let expected = try #require(store.sessionSnapshot()?.id)
    let (authorizing, updater) = SessionFactory.authorization(
      store: store,
      refresher: StubTokenRefresher(result: .success(renewed))
    )
    let replacement = FestiCoreCredential(accessToken: "account-b", refreshToken: "refresh-b")
    store.save(replacement)
    updater.update(replacement)
    let session = Session(startRequestsImmediately: false)
    let request = session.request("https://festicore.test/private")
    let result = await withCheckedContinuation { continuation in
      authorizing.bound(to: expected).retry(
        request, for: session, dueTo: URLError(.userAuthenticationRequired)
      ) { continuation.resume(returning: $0) }
    }
    guard case .doNotRetry = result else {
      Issue.record("이전 세션의 요청은 재시도하면 안 된다")
      return
    }
  }

  @Test("CredentialUpdater는 로그인과 로그아웃 credential을 같은 interceptor에 반영한다")
  func credentialUpdaterChangesSharedCredential() {
    let store = RecordingCredentialStore()
    let (authorizing, updater) = SessionFactory.authorization(
      store: store,
      refresher: StubTokenRefresher(result: .success(renewed))
    )

    updater.update(current)
    #expect(authorizing.base.credential == current)

    updater.update(nil)
    #expect(authorizing.base.credential == nil)
  }

  private func adapt(
    _ interceptor: AuthorizingInterceptor,
    request: URLRequest
  ) async throws -> URLRequest {
    try await withCheckedThrowingContinuation { continuation in
      interceptor.adapt(request, for: Session()) { result in
        continuation.resume(with: result)
      }
    }
  }

  private func refresh(
    _ authenticator: FestiCoreAuthenticator,
    credential: FestiCoreCredential
  ) async throws -> FestiCoreCredential {
    try await withCheckedThrowingContinuation { continuation in
      authenticator.refresh(credential, for: Session()) { result in
        continuation.resume(with: result)
      }
    }
  }
}

private struct StubTokenRefresher: TokenRefreshing {
  let result: Result<FestiCoreCredential, FestiCoreNetworkError>

  func refresh(_ current: FestiCoreCredential, sessionID _: UUID) async throws(FestiCoreNetworkError) -> FestiCoreCredential {
    try result.get()
  }
}

private actor SuspendedTokenRefresher: TokenRefreshing {
  private var started = false
  private var startedContinuation: CheckedContinuation<Void, Never>?
  private var resultContinuation: CheckedContinuation<FestiCoreCredential, Never>?

  func refresh(_: FestiCoreCredential, sessionID _: UUID) async throws(FestiCoreNetworkError) -> FestiCoreCredential {
    await withCheckedContinuation { continuation in
      resultContinuation = continuation
      started = true
      startedContinuation?.resume()
      startedContinuation = nil
    }
  }

  func waitUntilStarted() async {
    guard !started else { return }
    await withCheckedContinuation { startedContinuation = $0 }
  }

  func complete(with credential: FestiCoreCredential) {
    resultContinuation?.resume(returning: credential)
    resultContinuation = nil
  }
}

private actor ContextCapturingRefresher: TokenRefreshing {
  private(set) var capturedSessionID: UUID?

  func refresh(
    _: FestiCoreCredential,
    sessionID: UUID
  ) async throws(FestiCoreNetworkError) -> FestiCoreCredential {
    capturedSessionID = sessionID
    throw .response(ResponseError(httpStatus: 401))
  }
}

private final class RecordingCredentialStore: CredentialStore, @unchecked Sendable {
  private let lock = NSLock()
  private var credential: FestiCoreCredential?
  private var currentRevision = UUID()
  private var currentSessionID = UUID()
  private var shouldReloginAfterRefreshContext = false

  init(initial: FestiCoreCredential? = nil) {
    credential = initial
  }

  var saved: FestiCoreCredential? {
    lock.withLock { credential }
  }

  func load() -> FestiCoreCredential? {
    lock.withLock { credential }
  }

  func sessionSnapshot() -> FestiCoreCredentialSession? {
    lock.withLock {
      credential.map { FestiCoreCredentialSession(credential: $0, id: currentSessionID) }
    }
  }

  func save(_ credential: FestiCoreCredential) {
    lock.withLock {
      self.credential = credential
      currentRevision = UUID()
      currentSessionID = UUID()
    }
  }

  func revision(matching current: FestiCoreCredential) -> UUID? {
    lock.withLock { credential == current ? currentRevision : nil }
  }

  func refreshContext(matching current: FestiCoreCredential) -> FestiCoreRefreshContext? {
    lock.withLock {
      guard credential == current else { return nil }
      let context = FestiCoreRefreshContext(sessionID: currentSessionID, revision: currentRevision)
      if shouldReloginAfterRefreshContext {
        shouldReloginAfterRefreshContext = false
        currentSessionID = UUID()
        currentRevision = UUID()
      }
      return context
    }
  }

  func reloginAfterNextRefreshContext() {
    lock.withLock { shouldReloginAfterRefreshContext = true }
  }

  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) -> Bool {
    lock.withLock {
      guard self.credential == current, currentRevision == revision else { return false }
      self.credential = credential
      currentRevision = UUID()
      return true
    }
  }

  func clear() {
    lock.withLock {
      credential = nil
      currentRevision = UUID()
      currentSessionID = UUID()
    }
  }
}
