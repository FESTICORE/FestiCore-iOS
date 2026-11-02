//
//  FestivalImageUseCase+Live.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

extension FestivalImageUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalImageUseCaseInterface { FestivalImageUseCaseImpl() }
}
