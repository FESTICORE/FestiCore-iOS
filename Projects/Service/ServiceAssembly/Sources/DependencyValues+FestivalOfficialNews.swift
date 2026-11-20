//
//  DependencyValues+FestivalOfficialNews.swift
//  ServiceAssembly
//
//  Created by FestiCore on 11/20/26.
//

import Dependencies
import FestivalDomainInterface

extension FestivalOfficialNewsServiceDependency: DependencyKey {
  public static var liveValue: any FestivalOfficialNewsService {
    return NetworkContainer.festivalOfficialNewsService
  }
}
