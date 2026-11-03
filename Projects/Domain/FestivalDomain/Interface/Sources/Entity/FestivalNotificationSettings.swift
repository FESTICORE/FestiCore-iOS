//
//  FestivalNotificationSettings.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

/// 기기에서 받을 알림 종류. 서버 기본값은 모두 켜짐이다.
public struct FestivalNotificationSettings: Equatable, Sendable {
  public var flagStatus: Bool
  public var crewStatus: Bool
  public var crewGather: Bool
  public var setReminders: Bool
  public var homecoming: Bool
  public var packUpdates: Bool

  public init(
    flagStatus: Bool = true, crewStatus: Bool = true, crewGather: Bool = true,
    setReminders: Bool = true, homecoming: Bool = true, packUpdates: Bool = true
  ) {
    self.flagStatus = flagStatus
    self.crewStatus = crewStatus
    self.crewGather = crewGather
    self.setReminders = setReminders
    self.homecoming = homecoming
    self.packUpdates = packUpdates
  }
}

/// 알림 설정 화면의 토글 하나에 해당하는 알림 종류
public enum FestivalNotificationKind: CaseIterable, Hashable, Sendable {
  case flagStatus
  case crewStatus
  case crewGather
  case setReminders
  case homecoming
  case packUpdates
}

public extension FestivalNotificationSettings {
  subscript(kind: FestivalNotificationKind) -> Bool {
    get {
      switch kind {
      case .flagStatus: flagStatus
      case .crewStatus: crewStatus
      case .crewGather: crewGather
      case .setReminders: setReminders
      case .homecoming: homecoming
      case .packUpdates: packUpdates
      }
    }
    set {
      switch kind {
      case .flagStatus: flagStatus = newValue
      case .crewStatus: crewStatus = newValue
      case .crewGather: crewGather = newValue
      case .setReminders: setReminders = newValue
      case .homecoming: homecoming = newValue
      case .packUpdates: packUpdates = newValue
      }
    }
  }
}

/// 기기 설정의 알림 허용 상태
public enum FestivalNotificationPermission: Equatable, Sendable {
  case allowed
  case denied
  case notDetermined
}

public enum FestivalNotificationSettingsError: Error, Equatable, Sendable {
  /// 기기 등록 전이라 기기 토큰이 없다.
  case deviceNotRegistered
  case invalidResponse
  case notRegistered
}
