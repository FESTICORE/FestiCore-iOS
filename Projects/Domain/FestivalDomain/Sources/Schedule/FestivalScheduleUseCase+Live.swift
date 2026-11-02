//
//  FestivalScheduleUseCase+Live.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface

extension FestivalScheduleUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalScheduleUseCaseInterface { FestivalScheduleUseCaseImpl() }
}
