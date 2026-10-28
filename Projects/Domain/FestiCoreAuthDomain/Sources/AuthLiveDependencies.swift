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
