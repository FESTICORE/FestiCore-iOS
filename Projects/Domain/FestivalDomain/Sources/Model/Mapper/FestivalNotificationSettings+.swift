//
//  FestivalNotificationSettings+.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import APIEndpoint
import FestivalDomainInterface

extension FestivalNotificationSettingsDataDTO {
  func toDomain() -> FestivalNotificationSettings {
    FestivalNotificationSettings(
      flagStatus: flagStatus, crewStatus: crewStatus, crewGather: crewGather,
      setReminders: setReminders, homecoming: homecoming, packUpdates: packUpdates
    )
  }
}

extension FestivalNotificationSettings {
  var requestBody: DeviceNotificationSettingsBody {
    DeviceNotificationSettingsBody(
      flagStatus: flagStatus, crewStatus: crewStatus, crewGather: crewGather,
      setReminders: setReminders, homecoming: homecoming, packUpdates: packUpdates
    )
  }
}
