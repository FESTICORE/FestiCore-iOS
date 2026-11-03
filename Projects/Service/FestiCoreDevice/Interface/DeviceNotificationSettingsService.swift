//
//  DeviceNotificationSettingsService.swift
//  FestiCoreDeviceInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 서버에 저장한 이 기기의 푸시 종류별 수신 여부
public struct DeviceNotificationSettings: Sendable, Equatable {
  public let flagStatus: Bool
  public let crewStatus: Bool
  public let crewGather: Bool
  public let setReminders: Bool
  public let homecoming: Bool
  public let packUpdates: Bool

  public init(
    flagStatus: Bool, crewStatus: Bool, crewGather: Bool,
    setReminders: Bool, homecoming: Bool, packUpdates: Bool
  ) {
    self.flagStatus = flagStatus
    self.crewStatus = crewStatus
    self.crewGather = crewGather
    self.setReminders = setReminders
    self.homecoming = homecoming
    self.packUpdates = packUpdates
  }
}

/// 바꿀 항목만 담는 요청. nil인 항목은 보내지 않아 서버 값을 그대로 둔다.
public struct DeviceNotificationSettingsChange: Sendable, Equatable, Encodable {
  public var flagStatus: Bool?
  public var crewStatus: Bool?
  public var crewGather: Bool?
  public var setReminders: Bool?
  public var homecoming: Bool?
  public var packUpdates: Bool?

  public init(
    flagStatus: Bool? = nil, crewStatus: Bool? = nil, crewGather: Bool? = nil,
    setReminders: Bool? = nil, homecoming: Bool? = nil, packUpdates: Bool? = nil
  ) {
    self.flagStatus = flagStatus
    self.crewStatus = crewStatus
    self.crewGather = crewGather
    self.setReminders = setReminders
    self.homecoming = homecoming
    self.packUpdates = packUpdates
  }
}

public enum DeviceNotificationSettingsError: Error, Equatable, Sendable {
  /// 기기 등록 정보가 없어 설정을 읽거나 바꿀 수 없다.
  case deviceNotRegistered
  case invalidResponse
}

/// `GET`·`PUT /api/v1/devices/notification-settings`를 기기 인증으로 부른다.
public protocol DeviceNotificationSettingsService: Sendable {
  func settings() async throws -> DeviceNotificationSettings
  func update(_ change: DeviceNotificationSettingsChange) async throws -> DeviceNotificationSettings
}

public enum DeviceNotificationSettingsServiceDependency: TestDependencyKey {
  public static var testValue: any DeviceNotificationSettingsService {
    UnimplementedDeviceNotificationSettingsService()
  }
}

public extension DependencyValues {
  var deviceNotificationSettingsService: any DeviceNotificationSettingsService {
    get { self[DeviceNotificationSettingsServiceDependency.self] }
    set { self[DeviceNotificationSettingsServiceDependency.self] = newValue }
  }
}

private struct UnimplementedDeviceNotificationSettingsService: DeviceNotificationSettingsService {
  func settings() async throws -> DeviceNotificationSettings {
    reportIssue("deviceNotificationSettingsService.settings 미등록")
    throw TestDeviceRegistrationUnavailable()
  }

  func update(_: DeviceNotificationSettingsChange) async throws -> DeviceNotificationSettings {
    reportIssue("deviceNotificationSettingsService.update 미등록")
    throw TestDeviceRegistrationUnavailable()
  }
}
