//
//  LiveActivityRegistrationService.swift
//  FestiCoreDeviceInterface
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies
import FestiCoreNetworkInterface
import Foundation

public struct DeviceAuthorization: Sendable {
  public let deviceID: String
  public let bearerToken: String?
  public let sessionID: UUID?

  public init(deviceID: String, bearerToken: String) {
    self.deviceID = deviceID
    self.bearerToken = bearerToken
    sessionID = nil
  }

  public init(
    deviceID: String,
    sessionID: UUID
  ) {
    self.deviceID = deviceID
    bearerToken = nil
    self.sessionID = sessionID
  }
}

public struct LiveActivityRegistration: Sendable {
  public let festivalID: String
  public let activityID: String
  public let pushToken: String

  public init(festivalID: String, activityID: String, pushToken: String) {
    self.festivalID = festivalID
    self.activityID = activityID
    self.pushToken = pushToken
  }
}

public protocol LiveActivityRegistrationService: Sendable {
  func register(
    _ registration: LiveActivityRegistration,
    authorization: DeviceAuthorization
  ) async throws(FestiCoreNetworkError)

  func remove(authorization: DeviceAuthorization) async throws(FestiCoreNetworkError)
}

public enum LiveActivityRegistrationServiceDependency: TestDependencyKey {
  public static var testValue: any LiveActivityRegistrationService {
    return UnimplementedLiveActivityRegistrationService()
  }
}

public extension DependencyValues {
  var liveActivityRegistrationService: any LiveActivityRegistrationService {
    get {
      return self[LiveActivityRegistrationServiceDependency.self]
    }
    set { self[LiveActivityRegistrationServiceDependency.self] = newValue }
  }
}

private struct UnimplementedLiveActivityRegistrationService: LiveActivityRegistrationService {
  func register(
    _: LiveActivityRegistration,
    authorization _: DeviceAuthorization
  ) async throws(FestiCoreNetworkError) {
    throw .request(.dependencyNotRegistered("liveActivityRegistrationService"))
  }

  func remove(authorization _: DeviceAuthorization) async throws(FestiCoreNetworkError) {
    throw .request(.dependencyNotRegistered("liveActivityRegistrationService"))
  }
}
