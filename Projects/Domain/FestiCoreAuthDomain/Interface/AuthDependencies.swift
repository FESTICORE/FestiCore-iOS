//
//  AuthDependencies.swift
//  FestiCoreAuthDomainInterface
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies

public enum AuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any AuthRepository { UnimplementedAuthDependency() }
}

public enum AuthUseCaseDependency: TestDependencyKey {
  public static var testValue: any AuthUseCase { UnimplementedAuthDependency() }
}

public extension DependencyValues {
  var authRepository: any AuthRepository {
    get { self[AuthRepositoryDependency.self] }
    set { self[AuthRepositoryDependency.self] = newValue }
  }

  var authUseCase: any AuthUseCase {
    get { self[AuthUseCaseDependency.self] }
    set { self[AuthUseCaseDependency.self] = newValue }
  }
}

private struct UnimplementedAuthDependency: AuthRepository, AuthUseCase {
  func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    fatalError("authRepository 또는 authUseCase 미등록")
  }

  func signOut() async throws {
    fatalError("authRepository 또는 authUseCase 미등록")
  }
}
