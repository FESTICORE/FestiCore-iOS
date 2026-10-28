//
//  AppleOAuthTests.swift
//  FestiCoreAuthDomainTests
//
//  Created by FestiCore on 10/29/26.
//

import AuthenticationServices
import FestiCoreAuthDomainInterface
import Foundation
import Testing
@testable import FestiCoreAuthDomain

@Suite("Apple 네이티브 인증")
struct AppleOAuthTests {
  @Test("identity token과 authorization code가 모두 있어야 한다")
  func requiredValues() throws {
    let credential = try AppleOAuthCredentialMapper.map(
      identityToken: Data("identity".utf8),
      authorizationCode: Data("code".utf8),
      fullName: nil
    )
    #expect(credential == .apple(idToken: "identity", authorizationCode: "code"))

    #expect(throws: AuthDomainError.missingIDToken) {
      try AppleOAuthCredentialMapper.map(
        identityToken: nil, authorizationCode: Data("code".utf8), fullName: nil
      )
    }
    #expect(throws: AuthDomainError.missingAuthorizationCode) {
      try AppleOAuthCredentialMapper.map(
        identityToken: Data("identity".utf8), authorizationCode: Data(), fullName: nil
      )
    }
    #expect(throws: AuthDomainError.missingIDToken) {
      try AppleOAuthCredentialMapper.map(
        identityToken: Data([0xFF]), authorizationCode: Data("code".utf8), fullName: nil
      )
    }
  }

  @Test("최초 제공 이름을 지역화된 표시 이름으로 변환한다")
  func fullName() throws {
    var components = PersonNameComponents()
    components.givenName = "원지"
    components.familyName = "서"
    let expected = PersonNameComponentsFormatter().string(from: components)
    let credential = try AppleOAuthCredentialMapper.map(
      identityToken: Data("identity".utf8),
      authorizationCode: Data("code".utf8),
      fullName: components
    )
    #expect(credential == .apple(idToken: "identity", authorizationCode: "code", name: expected))
  }

  @Test("진행 중인 인증 요청은 거절하고 늦은 완료는 무시한다")
  @MainActor
  func singleFlight() async throws {
    let flow = AppleOAuthFlow(anchorProvider: { ASPresentationAnchor() }, requestStarter: { _ in })
    let first = Task { try await flow.credential() }
    while !flow.hasPendingRequest { await Task.yield() }

    await #expect(throws: AuthDomainError.requestInProgress) {
      try await flow.credential()
    }
    let expected = AuthCredential.apple(idToken: "identity", authorizationCode: "code")
    flow.finish(.success(expected))
    flow.finish(.failure(AuthDomainError.providerFailure))
    #expect(try await first.value == expected)
  }

  @Test("이전 요청의 늦은 콜백은 새 요청을 끝내지 않는다")
  @MainActor
  func staleCallback() async throws {
    var controllers: [ASAuthorizationController] = []
    let flow = AppleOAuthFlow(anchorProvider: { ASPresentationAnchor() }) {
      controllers.append($0)
    }
    let credential = AuthCredential.apple(idToken: "identity", authorizationCode: "code")
    let first = Task { try await flow.credential() }
    while controllers.count < 1 { await Task.yield() }
    let oldRequestID = try #require(flow.pendingRequestID)
    flow.finish(.success(credential))
    _ = try await first.value

    let second = Task { try await flow.credential() }
    while controllers.count < 2 { await Task.yield() }
    flow.cancel(requestID: oldRequestID)
    #expect(flow.hasPendingRequest)
    flow.authorizationController(
      controller: controllers[0],
      didCompleteWithError: NSError(domain: "stale", code: 1)
    )
    #expect(flow.hasPendingRequest)
    flow.finish(.success(credential))
    #expect(try await second.value == credential)
  }

  @Test("Apple 사용자 취소와 제공자 오류를 구별한다")
  @MainActor
  func providerErrors() async {
    var controllers: [ASAuthorizationController] = []
    let flow = AppleOAuthFlow(anchorProvider: { ASPresentationAnchor() }) {
      controllers.append($0)
    }
    let cancelled = Task { try await flow.credential() }
    while controllers.count < 1 { await Task.yield() }
    flow.authorizationController(
      controller: controllers[0],
      didCompleteWithError: NSError(
        domain: ASAuthorizationError.errorDomain,
        code: ASAuthorizationError.canceled.rawValue
      )
    )
    await #expect(throws: AuthDomainError.userCancelled) { try await cancelled.value }

    let failed = Task { try await flow.credential() }
    while controllers.count < 2 { await Task.yield() }
    flow.authorizationController(
      controller: controllers[1],
      didCompleteWithError: NSError(domain: "other", code: ASAuthorizationError.canceled.rawValue)
    )
    await #expect(throws: AuthDomainError.providerFailure) { try await failed.value }
  }

  @Test("호출자가 취소하면 진행 중인 인증도 완료된다")
  @MainActor
  func cancellation() async {
    let flow = AppleOAuthFlow(anchorProvider: { ASPresentationAnchor() }, requestStarter: { _ in })
    let task = Task { try await flow.credential() }
    while !flow.hasPendingRequest { await Task.yield() }
    task.cancel()
    await #expect(throws: AuthDomainError.userCancelled) {
      try await task.value
    }
    #expect(!flow.hasPendingRequest)
  }
}
