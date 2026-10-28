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

public enum GoogleOAuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any GoogleOAuthRepository { UnimplementedGoogleOAuthRepository() }
}

public enum AppleOAuthRepositoryDependency: TestDependencyKey {
  public static var testValue: any AppleOAuthRepository { UnimplementedAppleOAuthRepository() }
}

public enum OAuthUseCaseDependency: TestDependencyKey {
  public static var testValue: any OAuthUseCase { UnimplementedOAuthUseCase() }
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

  var googleOAuthRepository: any GoogleOAuthRepository {
    get { self[GoogleOAuthRepositoryDependency.self] }
    set { self[GoogleOAuthRepositoryDependency.self] = newValue }
  }

  var appleOAuthRepository: any AppleOAuthRepository {
    get { self[AppleOAuthRepositoryDependency.self] }
    set { self[AppleOAuthRepositoryDependency.self] = newValue }
  }

  var oauthUseCase: any OAuthUseCase {
    get { self[OAuthUseCaseDependency.self] }
    set { self[OAuthUseCaseDependency.self] = newValue }
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

private struct UnimplementedGoogleOAuthRepository: GoogleOAuthRepository {
  func credential() async throws -> AuthCredential {
    fatalError("googleOAuthRepository 미등록")
  }
}

private struct UnimplementedAppleOAuthRepository: AppleOAuthRepository {
  func credential() async throws -> AuthCredential {
    fatalError("appleOAuthRepository 미등록")
  }
}

private struct UnimplementedOAuthUseCase: OAuthUseCase {
  func signIn(provider: OAuthProvider) async throws -> AuthLoginResult {
    fatalError("oAuthUseCase 미등록")
  }
}
