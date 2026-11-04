//
//  NetworkLiveActivityRegistrationService.swift
//  FestiCoreDevice
//
//  Created by FestiCore on 10/24/26.
//

import Alamofire
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface

public struct NetworkLiveActivityRegistrationService: LiveActivityRegistrationService {
  private let client: any FestiCoreRequestClient

  public init(client: any FestiCoreRequestClient) {
    self.client = client
  }

  public func register(
    _ registration: LiveActivityRegistration,
    authorization: DeviceAuthorization
  ) async throws(FestiCoreNetworkError) {
    _ = try await client.send(LiveActivityRegistrationRequest(
      method: .put,
      authorization: authorization,
      registration: registration
    ))
  }

  public func remove(authorization: DeviceAuthorization) async throws(FestiCoreNetworkError) {
    _ = try await client.send(LiveActivityRegistrationRequest(
      method: .delete,
      authorization: authorization,
      registration: nil
    ))
  }
}

struct LiveActivityRegistrationRequest: FestiCoreDataRequest {
  typealias Response = FestiCoreEmptyResponse

  let method: HTTPMethod
  let deviceAuthorization: DeviceAuthorization
  let registration: LiveActivityRegistration?

  init(
    method: HTTPMethod,
    authorization: DeviceAuthorization,
    registration: LiveActivityRegistration?
  ) {
    self.method = method
    deviceAuthorization = authorization
    self.registration = registration
  }

  var path: String { "api/v1/devices/live-activity" }
  var authorization: FestiCoreAuthorization {
    if let sessionID = deviceAuthorization.sessionID { return .sessionBound(sessionID) }
    return .none
  }
  var maxRetryAttempts: Int { 0 }
  var headers: HTTPHeaders {
    var headers: HTTPHeaders = ["X-Device-Id": deviceAuthorization.deviceID]
    if let token = deviceAuthorization.bearerToken {
      headers.add(
        name: "Authorization",
        value: "Bearer \(token)"
      )
    }
    return headers
  }
  var parameters: (any Encodable & Sendable)? {
    registration.map {
      LiveActivityBody(festivalId: $0.festivalID, activityId: $0.activityID, pushToken: $0.pushToken)
    }
  }
}

private struct LiveActivityBody: Encodable, Sendable {
  let festivalId: String
  let activityId: String
  let pushToken: String
}
