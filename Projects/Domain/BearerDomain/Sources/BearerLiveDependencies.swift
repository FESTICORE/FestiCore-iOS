//
//  BearerLiveDependencies.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Dependencies

extension BearerRepositoryDependency: DependencyKey {
  public static var liveValue: any BearerRepositoryInterface { BearerRepositoryImpl() }
}

extension BearerUseCaseDependency: DependencyKey {
  public static var liveValue: any BearerUseCaseInterface { BearerUseCaseImpl() }
}
