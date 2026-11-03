//
//  AuthInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public protocol AuthInterface: Sendable {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult
  func fetchProfile() async throws -> AuthProfile
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser
  /// 가입을 마친 계정의 닉네임만 바꾼다.
  func updateNickname(_ nickname: String) async throws -> AuthUser
  func signOut() async throws
  func withdraw() async throws
}

public enum AuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any AuthInterface { MockAuthRepository() }
  public static var previewValue: any AuthInterface { testValue }
}

public extension DependencyValues {
  var authRepository: any AuthInterface {
    get { self[AuthRepositoryDependency.self] }
    set { self[AuthRepositoryDependency.self] = newValue }
  }
}
