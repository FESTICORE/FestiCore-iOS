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

public enum DeviceRegistrationError: Error, Equatable, Sendable {
  case invalidResponse
  case accountMismatch
  case deviceNotRegistered
  case notAuthenticated
}

public struct DeviceUserSession: Sendable {
  public let id: UUID
  public let userID: String

  public init(
    id: UUID,
    userID: String
  ) {
    self.id = id
    self.userID = userID
  }
}

public actor NetworkDeviceRegistrationService: DeviceRegistrationService {
  private let client: any FestiCoreRequestClient
  private let storage: any SecureStorage
  private let userSession: @Sendable () async -> DeviceUserSession?
  private var lastRegisteredMetadata: DeviceRegistrationMetadata?
  private var needsTokenRestoration = false
  private var tokenRestorationTask: Task<Void, Error>?

  public init(
    client: any FestiCoreRequestClient,
    storage: any SecureStorage,
    userSession: @escaping @Sendable () async -> DeviceUserSession? = { nil }
  ) {
    self.client = client
    self.storage = storage
    self.userSession = userSession
  }

  public func register(_ metadata: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    let deviceID = try await installationDeviceID()
    let currentToken = try storage.load(.deviceAccessToken)
    let boundUserID = try storage.load(.deviceBoundUserID)
    let session = await userSession()
    if let boundUserID, boundUserID != session?.userID { throw DeviceRegistrationError.accountMismatch }
    let response = try await client.send(DeviceRegistrationRequest(
      deviceID: deviceID,
      bearerToken: boundUserID == nil ? currentToken : nil,
      sessionID: boundUserID == nil ? nil : session?.id,
      metadata: metadata
    ))
    guard response.code == "SUCCESS", response.data.deviceId == deviceID else {
      throw DeviceRegistrationError.invalidResponse
    }
    if let session, boundUserID == session.userID {
      lastRegisteredMetadata = metadata
      needsTokenRestoration = false
      return DeviceAuthorization(deviceID: deviceID, sessionID: session.id)
    }
    guard let token = response.data.deviceAccessToken ?? currentToken, !token.isEmpty else {
      throw DeviceRegistrationError.invalidResponse
    }
    if token != currentToken {
      try storage.save(token, for: .deviceAccessToken)
    }
    lastRegisteredMetadata = metadata
    needsTokenRestoration = false
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
    guard let deviceID = try storage.load(.deviceID) else { return nil }
    if let boundUserID = try storage.load(.deviceBoundUserID) {
      guard let session = await userSession(), session.userID == boundUserID else { return nil }
      return DeviceAuthorization(deviceID: deviceID, sessionID: session.id)
    }
    guard let token = try storage.load(.deviceAccessToken), !token.isEmpty else { return nil }
    return DeviceAuthorization(deviceID: deviceID, bearerToken: token)
  }

  public func bindToCurrentUser() async throws {
    guard let session = await userSession() else { throw DeviceRegistrationError.notAuthenticated }
    let deviceID = try await installationDeviceID()
    if let boundUserID = try storage.load(.deviceBoundUserID) {
      if boundUserID == session.userID {
        try await restorePushTokensIfNeeded()
        return
      }
      try await recoverBoundDevice()
    }
    guard let token = try storage.load(.deviceAccessToken), !token.isEmpty else {
      throw DeviceRegistrationError.deviceNotRegistered
    }
    let response = try await client.send(DeviceUserBindingRequest(
      operation: .bind(token), deviceID: deviceID, sessionID: session.id
    ))
    guard response.code == "SUCCESS", response.data.deviceId == deviceID,
          response.data.userId == session.userID else { throw DeviceRegistrationError.invalidResponse }
    try storage.save(session.userID, for: .deviceBoundUserID)
    try? storage.remove(.deviceUnbindKey)
    try await restorePushTokensIfNeeded()
  }

  public func unbindCurrentUser() async throws {
    guard let boundUserID = try storage.load(.deviceBoundUserID) else { return }
    guard let session = await userSession(), session.userID == boundUserID else {
      throw DeviceRegistrationError.accountMismatch
    }
    let deviceID = try await installationDeviceID()
    let unbindKey = try pendingUnbindKey()
    let response = try await client.send(DeviceUserBindingRequest(
      operation: .unbind(unbindKey), deviceID: deviceID, sessionID: session.id
    ))
    guard response.code == "SUCCESS", response.data.deviceId == deviceID,
          response.data.userId == nil,
          let token = response.data.deviceAccessToken, !token.isEmpty else {
      throw DeviceRegistrationError.invalidResponse
    }
    needsTokenRestoration = true
    try storage.save(token, for: .deviceAccessToken)
    try storage.remove(.deviceBoundUserID)
    try storage.remove(.deviceUnbindKey)
  }

  public func recoverBoundDevice() async throws {
    guard try storage.load(.deviceBoundUserID) != nil else { return }
    let deviceID = try await installationDeviceID()
    guard let oldToken = try storage.load(.deviceAccessToken), !oldToken.isEmpty else {
      throw DeviceRegistrationError.deviceNotRegistered
    }
    let unbindKey = try pendingUnbindKey()
    let request = DeviceUserBindingRequest(
      operation: .recover(oldToken, unbindKey), deviceID: deviceID, sessionID: nil
    )
    let response: DeviceUserBindingRequest.Response
    do {
      response = try await client.send(request)
    } catch {
      guard case let .response(failure) = error, failure.isUnauthorized else { throw error }
      response = try await client.send(DeviceUserBindingRequest(
        operation: .recover(nil, unbindKey), deviceID: deviceID, sessionID: nil
      ))
    }
    guard response.code == "SUCCESS", response.data.deviceId == deviceID,
          response.data.userId == nil,
          let token = response.data.deviceAccessToken, !token.isEmpty else {
      throw DeviceRegistrationError.invalidResponse
    }
    needsTokenRestoration = true
    try storage.save(token, for: .deviceAccessToken)
    try storage.remove(.deviceBoundUserID)
    try storage.remove(.deviceUnbindKey)
  }

  /// 서버의 연결 해제는 푸시 토큰도 지운다. 같은 프로세스의 재로그인은
  /// APNs 콜백이 다시 오지 않아도 마지막 등록 정보를 한 번 복원한다.
  private func restorePushTokensIfNeeded() async throws {
    guard needsTokenRestoration, let metadata = lastRegisteredMetadata else { return }
    if let task = tokenRestorationTask {
      return try await task.value
    }
    let task = Task { _ = try await self.register(metadata) }
    tokenRestorationTask = task
    defer { tokenRestorationTask = nil }
    try await task.value
  }

  private func pendingUnbindKey() throws -> String {
    if let pendingKey = try storage.load(.deviceUnbindKey) { return pendingKey }
    let key = UUID().uuidString.lowercased()
    try storage.save(key, for: .deviceUnbindKey)
    return key
  }
}

struct DeviceRegistrationRequest: FestiCoreDataRequest {
  typealias Response = DeviceRegistrationEnvelope

  let deviceID: String
  let bearerToken: String?
  var sessionID: UUID?
  let metadata: DeviceRegistrationMetadata

  var path: String { "api/v1/devices" }
  var method: HTTPMethod { .put }
  var authorization: FestiCoreAuthorization {
    if let sessionID { return .sessionBound(sessionID) }
    return .none
  }
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

struct DeviceUserBindingRequest: FestiCoreDataRequest {
  typealias Response = BaseResponseDTO<DeviceUserBindingResult>

  enum Operation { case bind(String), unbind(String), recover(String?, String) }

  let operation: Operation
  let deviceID: String
  let sessionID: UUID?

  var path: String {
    if case .recover = operation { return "api/v1/devices/bind-user/recover" }
    return "api/v1/devices/bind-user"
  }
  var method: HTTPMethod {
    switch operation {
    case .bind: return .put
    case .unbind, .recover: return .delete
    }
  }
  var authorization: FestiCoreAuthorization {
    guard let sessionID else { return .none }
    return .sessionBound(sessionID)
  }
  var maxRetryAttempts: Int { return 0 }
  var headers: HTTPHeaders {
    var headers: HTTPHeaders = ["X-Device-Id": deviceID]
    switch operation {
    case let .bind(token):
      headers.add(name: "X-Device-Access-Token", value: token)
    case let .unbind(key):
      headers.add(name: "X-Device-Unbind-Key", value: key)
    case let .recover(token, key):
      headers.add(name: "X-Device-Unbind-Key", value: key)
      if let token { headers.add(name: "Authorization", value: "Bearer \(token)") }
    }
    return headers
  }
  var parameters: (any Encodable & Sendable)? { return nil }
}

struct DeviceUserBindingResult: Decodable, Sendable {
  let deviceId: String
  let userId: String?
  let deviceAccessToken: String?
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
