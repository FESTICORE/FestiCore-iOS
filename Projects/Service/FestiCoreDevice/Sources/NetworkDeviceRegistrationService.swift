//
//  NetworkDeviceRegistrationService.swift
//  FestiCoreDevice
//
//  Created by FestiCore on 10/24/26.
//

import Foundation
import Alamofire
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestiCoreStorageInterface

public enum DeviceRegistrationError: Error, Sendable {
  case invalidResponse
}

public actor NetworkDeviceRegistrationService: DeviceRegistrationService {
  private let client: any FestiCoreRequestClient
  private let storage: any SecureStorage

  public init(client: any FestiCoreRequestClient, storage: any SecureStorage) {
    self.client = client
    self.storage = storage
  }

  public func register(_ metadata: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    let deviceID = try await installationDeviceID()
    let currentToken = try storage.load(.deviceAccessToken)
    let response = try await client.send(DeviceRegistrationRequest(
      deviceID: deviceID,
      bearerToken: currentToken,
      metadata: metadata
    ))
    guard response.code == "SUCCESS", response.data.deviceId == deviceID else {
      throw DeviceRegistrationError.invalidResponse
    }
    guard let token = response.data.deviceAccessToken ?? currentToken, !token.isEmpty else {
      throw DeviceRegistrationError.invalidResponse
    }
    if token != currentToken {
      try storage.save(token, for: .deviceAccessToken)
    }
    return DeviceAuthorization(deviceID: deviceID, bearerToken: token)
  }

  public func installationDeviceID() async throws -> String {
    let deviceID: String
    if let storedID = try storage.load(.deviceID) {
      deviceID = storedID
    } else {
      deviceID = UUID().uuidString.lowercased()
      try storage.save(deviceID, for: .deviceID)
    }
    return deviceID
  }

  public func authorization() async throws -> DeviceAuthorization? {
    guard let deviceID = try storage.load(.deviceID),
          let token = try storage.load(.deviceAccessToken), !token.isEmpty else {
      return nil
    }
    return DeviceAuthorization(deviceID: deviceID, bearerToken: token)
  }
}

struct DeviceRegistrationRequest: FestiCoreDataRequest {
  typealias Response = DeviceRegistrationEnvelope

  let deviceID: String
  let bearerToken: String?
  let metadata: DeviceRegistrationMetadata

  var path: String { "api/v1/devices" }
  var method: HTTPMethod { .put }
  var authorization: FestiCoreAuthorization { .none }
  // 같은 기기 ID로 재등록하므로 네트워크 계층의 일시적 오류 재시도를 사용한다.
  var maxRetryAttempts: Int { 2 }
  var headers: HTTPHeaders {
    var headers: HTTPHeaders = ["X-Device-Id": deviceID]
    if let bearerToken {
      headers.add(name: "Authorization", value: "Bearer \(bearerToken)")
    }
    return headers
  }
  var parameters: (any Encodable & Sendable)? {
    DeviceRegistrationBody(metadata: metadata)
  }
}

private struct DeviceRegistrationBody: Encodable, Sendable {
  let apnsEnvironment: DeviceRegistrationMetadata.APNsEnvironment
  let apnsToken: String?
  let liveActivityPushToStartToken: String?
  let appVersion: String
  let osVersion: String
  let locale: String
  let timezone: String

  init(metadata: DeviceRegistrationMetadata) {
    apnsEnvironment = metadata.apnsEnvironment
    apnsToken = metadata.apnsToken
    liveActivityPushToStartToken = metadata.liveActivityPushToStartToken
    appVersion = metadata.appVersion
    osVersion = metadata.osVersion
    locale = metadata.locale
    timezone = metadata.timezone
  }

  private enum CodingKeys: String, CodingKey {
    case apnsEnvironment, apnsToken, liveActivityPushToStartToken, appVersion, osVersion, locale, timezone
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(apnsEnvironment, forKey: .apnsEnvironment)
    if let apnsToken {
      try container.encode(apnsToken, forKey: .apnsToken)
    } else {
      try container.encodeNil(forKey: .apnsToken)
    }
    if let liveActivityPushToStartToken {
      try container.encode(liveActivityPushToStartToken, forKey: .liveActivityPushToStartToken)
    } else {
      try container.encodeNil(forKey: .liveActivityPushToStartToken)
    }
    try container.encode(appVersion, forKey: .appVersion)
    try container.encode(osVersion, forKey: .osVersion)
    try container.encode(locale, forKey: .locale)
    try container.encode(timezone, forKey: .timezone)
  }
}

typealias DeviceRegistrationEnvelope = BaseResponseDTO<DeviceRegistrationResult>

struct DeviceRegistrationResult: Decodable, Sendable {
  let deviceId: String
  let deviceAccessToken: String?
}
