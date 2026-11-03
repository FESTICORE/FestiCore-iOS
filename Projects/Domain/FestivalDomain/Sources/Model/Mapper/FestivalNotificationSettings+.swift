//
//  FestivalNotificationSettings+.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreDeviceInterface
import FestivalDomainInterface

extension DeviceNotificationSettings {
  func toDomain() -> FestivalNotificationSettings {
    FestivalNotificationSettings(
      flagStatus: flagStatus, crewStatus: crewStatus, crewGather: crewGather,
      setReminders: setReminders, homecoming: homecoming, packUpdates: packUpdates
    )
  }
}

extension DeviceNotificationSettingsChange {
  /// 바뀐 항목만 담아 나머지는 서버 값을 그대로 둔다.
  init(_ changes: [FestivalNotificationKind: Bool]) {
    self.init(
      flagStatus: changes[.flagStatus], crewStatus: changes[.crewStatus], crewGather: changes[.crewGather],
      setReminders: changes[.setReminders], homecoming: changes[.homecoming], packUpdates: changes[.packUpdates]
    )
  }
}
