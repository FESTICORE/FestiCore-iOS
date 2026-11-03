//
//  FestivalNotificationSettingsUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import APIEndpoint
import Dependencies
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestivalDomainInterface

public struct FestivalNotificationSettingsUseCaseImpl: FestivalNotificationSettingsUseCaseInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.deviceRegistrationService) private var deviceService
  @Dependency(\.festivalNotificationPermission) private var permissionClient

  public init() {}

  public func permission() async -> FestivalNotificationPermission {
    await permissionClient.status()
  }

  public func settings() async throws -> FestivalNotificationSettings {
    let device = try await authorization()
    let response = try await client.send(
      DeviceNotificationSettingsRequest.fetch(deviceID: device.deviceID, bearerToken: device.bearerToken),
      as: FestivalNotificationSettingsResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalNotificationSettingsError.invalidResponse }
    return response.data.toDomain()
  }

  public func updateSettings(_ settings: FestivalNotificationSettings) async throws -> FestivalNotificationSettings {
    let device = try await authorization()
    let response = try await client.send(
      DeviceNotificationSettingsRequest.update(
        settings.requestBody, deviceID: device.deviceID, bearerToken: device.bearerToken
      ),
      as: FestivalNotificationSettingsResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalNotificationSettingsError.invalidResponse }
    return response.data.toDomain()
  }

  private func authorization() async throws -> DeviceAuthorization {
    guard let device = try await deviceService.authorization() else {
      throw FestivalNotificationSettingsError.deviceNotRegistered
    }
    return device
  }
}
