//
//  FestivalNotificationSettingsUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCoreDeviceInterface
import FestivalDomainInterface

/// 기기 권한과 서버 알림 설정을 화면 계약으로 변환한다.
public struct FestivalNotificationSettingsUseCaseImpl: FestivalNotificationSettingsUseCaseInterface {
  @Dependency(\.deviceNotificationSettingsService) private var settingsService
  @Dependency(\.festivalNotificationPermission) private var permissionClient

  public init() {}

  /// 기기에서 현재 알림 권한을 읽는다.
  public func permission() async -> FestivalNotificationPermission {
    await permissionClient.status()
  }

  /// 서버 설정을 도메인 값으로 변환해 돌려준다.
  public func settings() async throws -> FestivalNotificationSettings {
    try await mapErrors { try await settingsService.settings().toDomain() }
  }

  /// 변경한 알림 종류만 보내고 전체 설정을 돌려준다.
  public func updateSettings(_ changes: [FestivalNotificationKind: Bool]) async throws -> FestivalNotificationSettings {
    try await mapErrors { try await settingsService.update(DeviceNotificationSettingsChange(changes)).toDomain() }
  }

  private func mapErrors(
    _ operation: () async throws -> FestivalNotificationSettings
  ) async throws -> FestivalNotificationSettings {
    do {
      return try await operation()
    } catch DeviceNotificationSettingsError.deviceNotRegistered {
      throw FestivalNotificationSettingsError.deviceNotRegistered
    } catch DeviceNotificationSettingsError.invalidResponse {
      throw FestivalNotificationSettingsError.invalidResponse
    }
  }
}
