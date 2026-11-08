//
//  MockLocationClient.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록하고 위치를 쓰지 않는 쪽으로 답한다.
public struct MockLocationClient: LocationClient {
  public var authorizationHandler: @Sendable () async -> LocationAuthorization
  public var requestWhenInUseAuthorizationHandler: @Sendable () async -> LocationAuthorization
  public var currentLocationHandler: @Sendable () async throws -> LocationCoordinate

  public init(
    authorization: @escaping @Sendable () async -> LocationAuthorization = {
      reportIssue("locationClient.authorization 미등록")
      return .denied
    },
    requestWhenInUseAuthorization: @escaping @Sendable () async -> LocationAuthorization = {
      reportIssue("locationClient.requestWhenInUseAuthorization 미등록")
      return .denied
    },
    currentLocation: @escaping @Sendable () async throws -> LocationCoordinate = {
      reportIssue("locationClient.currentLocation 미등록")
      throw LocationClientError.notRegistered
    }
  ) {
    authorizationHandler = authorization
    requestWhenInUseAuthorizationHandler = requestWhenInUseAuthorization
    currentLocationHandler = currentLocation
  }

  public func authorization() async -> LocationAuthorization {
    return await authorizationHandler()
  }

  public func requestWhenInUseAuthorization() async -> LocationAuthorization {
    return await requestWhenInUseAuthorizationHandler()
  }

  public func currentLocation() async throws -> LocationCoordinate {
    return try await currentLocationHandler()
  }
}
