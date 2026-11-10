//
//  AuthUseCaseInterface.swift
//  AuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import Foundation

/// Feature·코디네이터가 쓰는 로그인·프로필·계정 작업과 임시 세션 확정의 계약이다.
/// 토큰 저장과 통신은 구현이 Repository에 맡기며, Feature는 이 계약만 주입받는다.
public protocol AuthUseCaseInterface: Sendable {
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

extension MockAuthRepository: AuthUseCaseInterface {}

public enum AuthUseCaseDependency: TestDependencyKey {
  public static var testValue: any AuthUseCaseInterface { MockAuthRepository(dependencyName: "authUseCase") }
  public static var previewValue: any AuthUseCaseInterface { testValue }
}

public extension DependencyValues {
  var authUseCase: any AuthUseCaseInterface {
    get { self[AuthUseCaseDependency.self] }
    set { self[AuthUseCaseDependency.self] = newValue }
  }
}
