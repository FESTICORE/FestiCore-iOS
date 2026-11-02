//
//  FestivalPackLiveDependencies.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface

extension FestivalReceivedPackUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalReceivedPackUseCaseInterface { FestivalReceivedPackUseCaseImpl() }
}
