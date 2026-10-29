//
//  DeviceRegistrationService.swift
//  FestiCoreDeviceInterface
//
//  Created by FestiCore on 10/24/26.
//

import Dependencies

public struct DeviceRegistrationMetadata: Sendable {
  public enum APNsEnvironment: String, Sendable, Encodable {
    case sandbox
    case production
  }

  public let apnsEnvironment: APNsEnvironment
  public let apnsToken: String?
  public let liveActivityPushToStartToken: String?
  public let appVersion: String
  public let osVersion: String
  public let locale: String
  public let timezone: String

  public init(
    apnsEnvironment: APNsEnvironment,
    apnsToken: String?,
    liveActivityPushToStartToken: String? = nil,
    appVersion: String,
    osVersion: String,
    locale: String,
    timezone: String
  ) {
    self.apnsEnvironment = apnsEnvironment
    self.apnsToken = apnsToken
    self.liveActivityPushToStartToken = liveActivityPushToStartToken
    self.appVersion = appVersion
    self.osVersion = osVersion
    self.locale = locale
    self.timezone = timezone
  }
}

public protocol DeviceRegistrationService: Sendable {
  func register(_ metadata: DeviceRegistrationMetadata) async throws -> DeviceAuthorization
  func authorization() async throws -> DeviceAuthorization?
}

public enum DeviceRegistrationServiceDependency: TestDependencyKey {
  public static var testValue: any DeviceRegistrationService { UnimplementedDeviceRegistrationService() }
}

public extension DependencyValues {
  var deviceRegistrationService: any DeviceRegistrationService {
    get { self[DeviceRegistrationServiceDependency.self] }
    set { self[DeviceRegistrationServiceDependency.self] = newValue }
  }
}

private struct UnimplementedDeviceRegistrationService: DeviceRegistrationService {
  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    throw TestDeviceRegistrationUnavailable()
  }

  func authorization() async throws -> DeviceAuthorization? {
    fatalError("deviceRegistrationService 미등록")
  }
}

struct TestDeviceRegistrationUnavailable: Error {}
