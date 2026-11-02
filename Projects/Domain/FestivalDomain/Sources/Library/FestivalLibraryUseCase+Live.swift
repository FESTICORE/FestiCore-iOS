//
//  FestivalLibraryUseCase+Live.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

extension FestivalLibraryUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLibraryUseCaseInterface { FestivalLibraryUseCaseImpl() }
}
