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

extension FestivalPackDetailUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalPackDetailUseCaseInterface { FestivalPackDetailUseCaseImpl() }
}

extension FestivalPackRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalPackRepositoryInterface { FestivalPackRepositoryImpl() }
}

extension FestivalNotificationSettingsUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalNotificationSettingsUseCaseInterface {
    FestivalNotificationSettingsUseCaseImpl()
  }
}

extension FestivalFlagDetailRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalFlagDetailRepositoryInterface { return FestivalFlagDetailRepositoryImpl() }
}

extension FestivalFlagDetailUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalFlagDetailUseCaseInterface { return FestivalFlagDetailUseCaseImpl() }
}
