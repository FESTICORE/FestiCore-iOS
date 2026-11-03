//
//  FestivalNotificationSettingsUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCoreDeviceInterface
import FestivalDomainInterface

public struct FestivalNotificationSettingsUseCaseImpl: FestivalNotificationSettingsUseCaseInterface {
  @Dependency(\.deviceNotificationSettingsService) private var settingsService
  @Dependency(\.festivalNotificationPermission) private var permissionClient

  public init() {}

  public func permission() async -> FestivalNotificationPermission {
    await permissionClient.status()
  }

  public func settings() async throws -> FestivalNotificationSettings {
    try await mapErrors { try await settingsService.settings().toDomain() }
  }

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
