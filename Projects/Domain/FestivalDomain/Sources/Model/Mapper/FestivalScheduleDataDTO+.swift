//
//  FestivalScheduleDataDTO+.swift
//  FestivalDomain
//
//  Created by FestiCore on 10/31/26.
//

import FestivalDomainInterface

public extension FestivalScheduleDataDTO {
  func toDomain() -> FestivalSchedule {
    .init(setIDs: setIds)
  }
}
