//
//  AuthInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import Foundation

/// 인증 API 요청과 공용 인증 세션 저장을 묶는 Repository 계약이다.
/// UseCase 구현만 이 계약을 쓰며, 응답 DTO는 Entity로 바꿔 돌려준다.
public protocol AuthInterface: Sendable {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult
  func fetchProfile() async throws -> AuthProfile
  func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser
  /// 가입을 마친 계정의 닉네임만 바꾼다.
  func updateNickname(_ nickname: String) async throws -> AuthUser
  func signOut() async throws
  func withdraw() async throws
  /// 로그인 응답으로 받은 임시 세션을 확정한다. 확정했으면 `true`.
  func commitSession(_ id: UUID) async -> Bool
  /// 확정 전의 임시 세션을 버린다. 버렸으면 `true`.
  func discardSession(_ id: UUID) async -> Bool
  /// 확정된 세션이 `id`일 때만 로그아웃한다. 로그아웃했으면 `true`.
  func signOut(ifSession id: UUID) async -> Bool
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
