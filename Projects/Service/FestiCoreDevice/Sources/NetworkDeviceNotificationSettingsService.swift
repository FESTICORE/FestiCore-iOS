//
//  NetworkDeviceNotificationSettingsService.swift
//  FestiCoreDevice
//
//  Created by FestiCore on 11/3/26.
//

import Alamofire
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import Foundation

public struct NetworkDeviceNotificationSettingsService: DeviceNotificationSettingsService {
  private let client: any FestiCoreRequestClient
  private let registration: any DeviceRegistrationService

  public init(client: any FestiCoreRequestClient, registration: any DeviceRegistrationService) {
    self.client = client
    self.registration = registration
  }

  public func settings() async throws -> DeviceNotificationSettings {
    try await send(.fetch)
  }

  public func update(_ change: DeviceNotificationSettingsChange) async throws -> DeviceNotificationSettings {
    try await send(.update(change))
  }

  private func send(_ operation: DeviceNotificationSettingsRequest.Operation) async throws -> DeviceNotificationSettings {
    guard let device = try await registration.authorization() else {
      throw DeviceNotificationSettingsError.deviceNotRegistered
    }
    let response = try await client.send(DeviceNotificationSettingsRequest(
      operation: operation, deviceID: device.deviceID, bearerToken: device.bearerToken
    ))
    guard response.code == "SUCCESS" else { throw DeviceNotificationSettingsError.invalidResponse }
    return response.data.settings
  }
}

struct DeviceNotificationSettingsRequest: FestiCoreDataRequest {
  typealias Response = DeviceNotificationSettingsEnvelope

  enum Operation {
    case fetch
    case update(DeviceNotificationSettingsChange)
  }

  let operation: Operation
  let deviceID: String
  let bearerToken: String

  var path: String { "api/v1/devices/notification-settings" }
  var method: HTTPMethod {
    switch operation {
    case .fetch: return .get
    case .update: return .put
    }
  }
  // 기기 토큰으로 인증하므로 사용자 세션 헤더를 붙이지 않는다.
  var authorization: FestiCoreAuthorization { .none }
  var maxRetryAttempts: Int { 0 }
  var headers: HTTPHeaders {
    ["X-Device-Id": deviceID, "Authorization": "Bearer \(bearerToken)"]
  }
  var parameters: (any Encodable & Sendable)? {
    switch operation {
    case .fetch: return nil
    case .update(let change): return change
    }
  }
}

struct DeviceNotificationSettingsEnvelope: Decodable, Sendable {
  struct Payload: Decodable, Sendable {
    let flagStatus: Bool
    let crewStatus: Bool
    let crewGather: Bool
    let setReminders: Bool
    let homecoming: Bool
    let packUpdates: Bool

    var settings: DeviceNotificationSettings {
      DeviceNotificationSettings(
        flagStatus: flagStatus, crewStatus: crewStatus, crewGather: crewGather,
        setReminders: setReminders, homecoming: homecoming, packUpdates: packUpdates
      )
    }
  }

  let code: String
  let data: Payload
}
