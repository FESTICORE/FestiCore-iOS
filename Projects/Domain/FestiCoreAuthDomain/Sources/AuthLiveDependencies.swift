//
//  AuthLiveDependencies.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import FestiCoreAuthDomainInterface

extension AuthRepositoryDependency: DependencyKey {
  public static var liveValue: any AuthRepository { AuthRepositoryImpl() }
}

extension AuthUseCaseDependency: DependencyKey {
  public static var liveValue: any AuthUseCase { AuthUseCaseImpl() }
}

extension GoogleOAuthRepositoryDependency: DependencyKey {
  public static var liveValue: any GoogleOAuthRepository { GoogleOAuthRepositoryImpl() }
}

extension AppleOAuthRepositoryDependency: DependencyKey {
  public static var liveValue: any AppleOAuthRepository { AppleOAuthRepositoryImpl() }
}

extension OAuthUseCaseDependency: DependencyKey {
  public static var liveValue: any OAuthUseCase { OAuthUseCaseImpl() }
}
