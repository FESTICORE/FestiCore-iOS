//
//  AuthDependencyDefaultsTests.swift
//  AuthDomainTests
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface
import Testing

@Suite("인증 의존성 기본값")
struct AuthDependencyDefaultsTests {
  @Test("미주입 UseCase는 이슈를 기록하고 오류를 반환한다")
  func missingUseCase() async {
    let captured = CapturedAuthError()
    await withKnownIssue("authUseCase 미등록") {
      do {
        try await AuthUseCaseDependency.testValue.signOut()
      } catch {
        await captured.set(error as? AuthDomainError)
      }
    }
    #expect(await captured.value == .configurationMissing)
  }
}

private actor CapturedAuthError {
  private(set) var value: AuthDomainError?

  func set(_ error: AuthDomainError?) {
    value = error
  }
}
