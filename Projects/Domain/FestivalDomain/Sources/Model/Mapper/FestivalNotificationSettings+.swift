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
    return FestivalNotificationSettings(
      flagStatus: flagStatus,
      crewStatus: crewStatus,
      crewGather: crewGather,
      setReminders: setReminders,
      homecoming: homecoming,
      packUpdates: packUpdates,
      // 이전 서버는 officialNews를 모른다. 그때는 기본값으로 두고 화면에서 숨긴다.
      officialNews: officialNews ?? true,
      isOfficialNewsAvailable: officialNews != nil
    )
  }
}

extension DeviceNotificationSettingsChange {
  /// 바뀐 항목만 담아 나머지는 서버 값을 그대로 둔다.
  init(_ changes: [FestivalNotificationKind: Bool]) {
    self.init(
      flagStatus: changes[.flagStatus],
      crewStatus: changes[.crewStatus],
      crewGather: changes[.crewGather],
      setReminders: changes[.setReminders],
      homecoming: changes[.homecoming],
      packUpdates: changes[.packUpdates],
      officialNews: changes[.officialNews]
    )
  }
}
