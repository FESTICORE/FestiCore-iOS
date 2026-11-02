//
//  FestivalLiveDependencies.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

extension FestivalCatalogUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogUseCaseInterface { FestivalCatalogUseCaseImpl() }
}

extension FestivalPackUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalPackUseCaseInterface { FestivalPackUseCaseImpl() }
}

extension FestivalLiveBoardUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLiveBoardUseCaseInterface { FestivalLiveBoardUseCaseImpl() }
}

extension FestivalLibraryUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLibraryUseCaseInterface { FestivalLibraryUseCaseImpl() }
}

extension FestivalFlagUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalFlagUseCaseInterface { FestivalFlagUseCaseImpl() }
}

extension FestivalLiveActivityUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLiveActivityUseCaseInterface { FestivalLiveActivityUseCaseImpl() }
}

extension FestivalImageUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalImageUseCaseInterface { FestivalImageUseCaseImpl() }
}
