//
//  GoogleOAuthTests.swift
//  FestiCoreAuthDomainTests
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreAuthDomainInterface
import Foundation
import GoogleSignIn
import Testing
import UIKit
@testable import FestiCoreAuthDomain

@Suite("Google OAuth")
@MainActor
struct GoogleOAuthTests {
  @Test("Google ID 토큰과 선택적 서버 코드를 매핑한다")
  func credentialMapping() throws {
    #expect(try GoogleOAuthTokens(idToken: "id", serverAuthCode: "code").credential()
      == .google(idToken: "id", serverAuthCode: "code"))
    #expect(try GoogleOAuthTokens(idToken: "id", serverAuthCode: "").credential()
      == .google(idToken: "id"))
    #expect(try GoogleOAuthTokens(idToken: "id", serverAuthCode: nil).credential()
      == .google(idToken: "id"))
    #expect(throws: AuthDomainError.missingIDToken) {
      try GoogleOAuthTokens(idToken: nil, serverAuthCode: nil).credential()
    }
    #expect(throws: AuthDomainError.missingIDToken) {
      try GoogleOAuthTokens(idToken: "", serverAuthCode: nil).credential()
    }
  }

  @Test("설정이 없으면 SDK와 presenter를 호출하지 않는다")
  func configurationMissing() async {
    var presenterCalled = false
    var sdkCalled = false
    let repository = GoogleOAuthRepositoryImpl(
      configuration: { nil },
      presentingController: { presenterCalled = true; return UIViewController() },
      signIn: { _, _ in sdkCalled = true; return .init(idToken: "id", serverAuthCode: nil) },
      signOut: {}, gate: GoogleOAuthRequestGate()
    )

    await #expect(throws: AuthDomainError.configurationMissing) {
      try await repository.credential()
    }
    #expect(!presenterCalled)
    #expect(!sdkCalled)
  }

  @Test("보이는 화면이 없으면 SDK를 호출하지 않는다")
  func presenterMissing() async {
    var sdkCalled = false
    let repository = GoogleOAuthRepositoryImpl(
      configuration: { .init(clientID: "client", serverClientID: nil) },
      presentingController: { nil },
      signIn: { _, _ in sdkCalled = true; return .init(idToken: "id", serverAuthCode: nil) },
      signOut: {}, gate: GoogleOAuthRequestGate()
    )

    await #expect(throws: AuthDomainError.missingPresentingController) {
      try await repository.credential()
    }
    #expect(!sdkCalled)
  }

  @Test("성공과 토큰 누락 모두 SDK 상태를 정리한다")
  func signsOutAfterSDKSuccess() async throws {
    var signOutCount = 0
    let success = GoogleOAuthRepositoryImpl(
      configuration: { .init(clientID: "client", serverClientID: "server") },
      presentingController: { UIViewController() },
      signIn: { configuration, _ in
        #expect(configuration.clientID == "client")
        #expect(configuration.serverClientID == "server")
        return .init(idToken: "id", serverAuthCode: "code")
      },
      signOut: { signOutCount += 1 }, gate: GoogleOAuthRequestGate()
    )
    #expect(try await success.credential() == .google(idToken: "id", serverAuthCode: "code"))
    #expect(signOutCount == 1)

    let missingToken = GoogleOAuthRepositoryImpl(
      configuration: { .init(clientID: "client", serverClientID: nil) },
      presentingController: { UIViewController() },
      signIn: { _, _ in .init(idToken: nil, serverAuthCode: nil) },
      signOut: { signOutCount += 1 }, gate: GoogleOAuthRequestGate()
    )
    await #expect(throws: AuthDomainError.missingIDToken) {
      try await missingToken.credential()
    }
    #expect(signOutCount == 2)
  }

  @Test("취소 후 SDK가 성공을 반환해도 상태를 정리한다")
  func cancellationAfterSDKSuccess() async {
    var resumeSignIn: CheckedContinuation<GoogleOAuthTokens, Never>?
    var signOutCount = 0
    let repository = GoogleOAuthRepositoryImpl(
      configuration: { .init(clientID: "client", serverClientID: nil) },
      presentingController: { UIViewController() },
      signIn: { _, _ in
        await withCheckedContinuation { resumeSignIn = $0 }
      },
      signOut: { signOutCount += 1 }, gate: GoogleOAuthRequestGate()
    )
    let request = Task { try await repository.credential() }
    while resumeSignIn == nil { await Task.yield() }
    request.cancel()
    resumeSignIn?.resume(returning: .init(idToken: "id", serverAuthCode: nil))

    await #expect(throws: AuthDomainError.userCancelled) { try await request.value }
    #expect(signOutCount == 1)
  }

  @Test("동시에 시작한 요청은 전역 gate가 거부한다")
  func overlappingRequests() async {
    let gate = GoogleOAuthRequestGate()
    var resumeSignIn: CheckedContinuation<GoogleOAuthTokens, Never>?
    let makeRepository = {
      GoogleOAuthRepositoryImpl(
        configuration: { .init(clientID: "client", serverClientID: nil) },
        presentingController: { UIViewController() },
        signIn: { _, _ in await withCheckedContinuation { resumeSignIn = $0 } },
        signOut: {}, gate: gate
      )
    }
    let first = makeRepository()
    let second = makeRepository()
    let request = Task { try await first.credential() }
    while resumeSignIn == nil { await Task.yield() }
    await #expect(throws: AuthDomainError.requestInProgress) { try await second.credential() }
    resumeSignIn?.resume(returning: .init(idToken: "id", serverAuthCode: nil))
    _ = try? await request.value
  }

  @Test("Google SDK 취소 오류는 사용자 취소로 매핑한다")
  func googleCancellationError() async {
    let repository = GoogleOAuthRepositoryImpl(
      configuration: { .init(clientID: "client", serverClientID: nil) },
      presentingController: { UIViewController() },
      signIn: { _, _ in
        throw NSError(domain: kGIDSignInErrorDomain, code: GIDSignInError.canceled.rawValue)
      },
      signOut: {}, gate: GoogleOAuthRequestGate()
    )

    await #expect(throws: AuthDomainError.userCancelled) {
      try await repository.credential()
    }
  }

  @Test("기타 SDK 오류는 providerFailure로 매핑한다")
  func providerError() async {
    let repository = GoogleOAuthRepositoryImpl(
      configuration: { .init(clientID: "client", serverClientID: nil) },
      presentingController: { UIViewController() },
      signIn: { _, _ in throw NSError(domain: "GoogleTestError", code: 42) },
      signOut: {}, gate: GoogleOAuthRequestGate()
    )

    await #expect(throws: AuthDomainError.providerFailure) {
      try await repository.credential()
    }
  }
}
