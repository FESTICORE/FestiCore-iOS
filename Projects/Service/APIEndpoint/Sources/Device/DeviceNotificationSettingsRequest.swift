//
//  DeviceNotificationSettingsRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/3/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface

/// 알림 종류별 수신 여부. 서버 계약의 이름을 그대로 쓴다.
public struct DeviceNotificationSettingsBody: Encodable, Sendable {
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

/// 기기 API는 X-Device-Id와 기기 토큰(또는 계정 기기면 계정 토큰)을 함께 보낸다.
public enum DeviceNotificationSettingsRequest: FestiCoreDataRequest, Sendable {
  case fetch(deviceID: String, bearerToken: String)
  case update(DeviceNotificationSettingsBody, deviceID: String, bearerToken: String)

  public var path: String { DeviceAPI.notificationSettings.path }

  public var method: HTTPMethod {
    switch self {
    case .fetch: return .get
    case .update: return .put
    }
  }

  public var authorization: FestiCoreAuthorization { .none }
  public var maxRetryAttempts: Int { 0 }

  public var headers: HTTPHeaders {
    switch self {
    case let .fetch(deviceID, token), let .update(_, deviceID, token):
      return ["X-Device-Id": deviceID, "Authorization": "Bearer \(token)"]
    }
  }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case .fetch: return nil
    case let .update(body, _, _): return body
    }
  }
}
