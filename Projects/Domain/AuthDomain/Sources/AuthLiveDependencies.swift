//
//  AuthLiveDependencies.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import AuthDomainInterface

extension AuthRepositoryDependency: DependencyKey {
  public static var liveValue: any AuthInterface { AuthRepositoryImpl() }
}

extension AuthUseCaseDependency: DependencyKey {
  public static var liveValue: any AuthUseCaseInterface { AuthUseCaseImpl() }
}

extension GoogleOAuthRepositoryDependency: DependencyKey {
  public static var liveValue: any GoogleOAuthInterface { GoogleOAuthRepositoryImpl() }
}

extension AppleOAuthRepositoryDependency: DependencyKey {
  public static var liveValue: any AppleOAuthInterface { AppleOAuthRepositoryImpl() }
}

extension OAuthUseCaseDependency: DependencyKey {
  public static var liveValue: any OAuthUseCaseInterface { OAuthUseCaseImpl() }
}
