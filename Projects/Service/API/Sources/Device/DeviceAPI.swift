//
//  DeviceAPI.swift
//  API
//
//  Created by FestiCore on 11/3/26.
//

public enum DeviceAPI: Sendable {
  /// 기기별 알림 종류 설정
  case notificationSettings

  public var path: String {
    switch self {
    case .notificationSettings: return "\(FestiCoreDomain.devices.path)/notification-settings"
    }
  }
}
