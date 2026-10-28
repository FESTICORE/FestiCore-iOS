//
//  OAuthUseCaseTests.swift
//  AuthDomainTests
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import AuthDomainInterface
import Testing
@testable import AuthDomain

@Suite("네이티브 인증과 서버 로그인 연결")
struct OAuthUseCaseTests {
  @Test("선택한 제공자의 인증 결과만 서버 로그인에 전달한다", arguments: [OAuthProvider.google, .apple])
  func forwardsCredential(provider: OAuthProvider) async throws {
    let server = RecordingAuthUseCase()
    let useCase = withDependencies {
      $0.googleOAuthRepository = StubGoogleOAuthRepository()
      $0.appleOAuthRepository = StubAppleOAuthRepository()
      $0.authUseCase = server
    } operation: { OAuthUseCaseImpl() }

    _ = try await useCase.signIn(provider: provider)
    let expected: AuthCredential = provider == .google
      ? .google(idToken: "google-id", serverAuthCode: "server-code")
      : .apple(idToken: "apple-id", authorizationCode: "apple-code")
    #expect(await server.received == [expected])
  }

  @Test(
    "네이티브 인증이 실패하면 서버 로그인을 호출하지 않는다",
    arguments: [OAuthProvider.google, .apple],
    [AuthDomainError.userCancelled, .providerFailure, .missingIDToken]
  )
  func nativeFailure(provider: OAuthProvider, error: AuthDomainError) async {
    let server = RecordingAuthUseCase()
    let useCase = withDependencies {
      $0.googleOAuthRepository = FailedGoogleOAuthRepository(error: error)
      $0.appleOAuthRepository = FailedAppleOAuthRepository(error: error)
      $0.authUseCase = server
    } operation: { OAuthUseCaseImpl() }

    await #expect(throws: error) {
      try await useCase.signIn(provider: provider)
    }
    #expect(await server.received.isEmpty)
  }
}

private struct StubGoogleOAuthRepository: GoogleOAuthRepository {
  func credential() async throws -> AuthCredential {
    .google(idToken: "google-id", serverAuthCode: "server-code")
  }
}

private struct FailedGoogleOAuthRepository: GoogleOAuthRepository {
  let error: AuthDomainError

  func credential() async throws -> AuthCredential { throw error }
}

private struct StubAppleOAuthRepository: AppleOAuthRepository {
  func credential() async throws -> AuthCredential {
    .apple(idToken: "apple-id", authorizationCode: "apple-code")
  }
}

private struct FailedAppleOAuthRepository: AppleOAuthRepository {
  let error: AuthDomainError

  func credential() async throws -> AuthCredential { throw error }
}

private actor RecordingAuthUseCase: AuthUseCase {
  private(set) var received: [AuthCredential] = []

  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    received.append(credential)
    return AuthLoginResult(
      newUser: false,
      user: AuthUser(
        id: "user", provider: "google", email: nil, nickname: nil,
        nicknameConfirmed: false, termsAcceptedAt: nil, termsVersion: nil,
        pushOptIn: false, profileImageURL: nil
      )
    )
  }

  func signOut() async throws {}
}
