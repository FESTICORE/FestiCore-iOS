//
//  LoginFeatureTests.swift
//  LoginTests
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface
import ComposableArchitecture
import Testing
@testable import Login

struct LoginFeatureTests {
  @Test @MainActor func successfulLoginReportsUser() async {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.oauthUseCase = ImmediateOAuth(result: .success(loginResult(newUser: true)))
    }

    await store.send(.view(.signIn(.google))) { $0.isSigningIn = true }
    await store.receive(\.inner.signInSucceeded) { $0.isSigningIn = false }
    await store.receive(.delegate(.signedIn(loginResult(newUser: true))))
  }

  @Test @MainActor func secondTapDoesNotStartAnotherRequest() async {
    let oauth = SuspendedOAuth()
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.oauthUseCase = oauth
    }

    await store.send(.view(.signIn(.google))) { $0.isSigningIn = true }
    await oauth.waitUntilStarted()
    await store.send(.view(.signIn(.apple)))
    #expect(await oauth.callCount == 1)

    await oauth.complete(with: loginResult(newUser: false))
    await store.receive(\.inner.signInSucceeded) { $0.isSigningIn = false }
    await store.receive(.delegate(.signedIn(loginResult(newUser: false))))
  }

  @Test @MainActor func ordinaryFailureShowsSafeMessage() async {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.oauthUseCase = ImmediateOAuth(result: .failure(AuthDomainError.providerFailure))
    }

    await store.send(.view(.signIn(.apple))) { $0.isSigningIn = true }
    await store.receive(\.inner.signInFailed) {
      $0.isSigningIn = false
      $0.errorMessage = "로그인에 실패했습니다. 다시 시도해 주세요."
    }
  }

  @Test @MainActor func unexpectedFailureShowsSafeMessage() async {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.oauthUseCase = ImmediateOAuth(result: .failure(UnexpectedFailure()))
    }

    await store.send(.view(.signIn(.google))) { $0.isSigningIn = true }
    await store.receive(\.inner.signInFailed) {
      $0.isSigningIn = false
      $0.errorMessage = "로그인에 실패했습니다. 다시 시도해 주세요."
    }
  }

  @Test(arguments: [AuthDomainError.userCancelled, .requestInProgress])
  @MainActor func cancelledOrContendedRequestIsSilent(_ error: AuthDomainError) async {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.oauthUseCase = ImmediateOAuth(result: .failure(error))
    }

    await store.send(.view(.signIn(.google))) { $0.isSigningIn = true }
    await store.receive(\.inner.signInFailed) { $0.isSigningIn = false }
    #expect(store.state.errorMessage == nil)
  }

  private func loginResult(newUser: Bool) -> AuthLoginResult {
    AuthLoginResult(
      newUser: newUser,
      user: AuthUser(
        id: "user_1", provider: "google", email: "person@example.com",
        nickname: nil, nicknameConfirmed: false, termsAcceptedAt: nil,
        termsVersion: nil, pushOptIn: false, profileImageURL: nil
      )
    )
  }
}

private struct ImmediateOAuth: OAuthUseCaseInterface {
  let result: Result<AuthLoginResult, any Error>

  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    try result.get()
  }
}

private struct UnexpectedFailure: Error {}

private actor SuspendedOAuth: OAuthUseCaseInterface {
  private(set) var callCount = 0
  private var resultContinuation: CheckedContinuation<AuthLoginResult, Error>?
  private var startedContinuation: CheckedContinuation<Void, Never>?

  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    callCount += 1
    startedContinuation?.resume()
    startedContinuation = nil
    return try await withCheckedThrowingContinuation { resultContinuation = $0 }
  }

  func waitUntilStarted() async {
    if callCount > 0 { return }
    await withCheckedContinuation { startedContinuation = $0 }
  }

  func complete(with result: AuthLoginResult) {
    resultContinuation?.resume(returning: result)
    resultContinuation = nil
  }
}
