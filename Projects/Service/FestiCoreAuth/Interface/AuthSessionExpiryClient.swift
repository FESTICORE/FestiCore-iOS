//
//  AuthSessionExpiryClient.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/31/26.
//

import Dependencies
import IssueReporting

/// 토큰 갱신이 실패해 인증 세션이 만료되는 순간을 알린다.
public struct AuthSessionExpiryClient: Sendable {
  public var events: @Sendable () -> AsyncStream<Void>

  public init(events: @escaping @Sendable () -> AsyncStream<Void>) {
    self.events = events
  }
}

public enum AuthSessionExpiryDependency: TestDependencyKey {
  public static var testValue: AuthSessionExpiryClient {
    AuthSessionExpiryClient(events: {
      reportIssue("authSessionExpiryClient 미등록")
      return AsyncStream { $0.finish() }
    })
  }
}

public extension DependencyValues {
  var authSessionExpiryClient: AuthSessionExpiryClient {
    get { self[AuthSessionExpiryDependency.self] }
    set { self[AuthSessionExpiryDependency.self] = newValue }
  }
}
