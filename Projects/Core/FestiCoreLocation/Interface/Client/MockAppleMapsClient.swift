//
//  MockAppleMapsClient.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록하고 실패로 답한다.
public struct MockAppleMapsClient: AppleMapsClient {
  public var walkingDurationHandler: @Sendable (
    LocationCoordinate,
    WalkingPlace
  ) async throws -> WalkingDuration
  public var openWalkingDirectionsHandler: @Sendable (WalkingPlace) async -> Bool

  public init(
    walkingDuration: @escaping @Sendable (
      LocationCoordinate,
      WalkingPlace
    ) async throws -> WalkingDuration = { _, _ in
      reportIssue("appleMapsClient.walkingDuration 미등록")
      throw LocationClientError.notRegistered
    },
    openWalkingDirections: @escaping @Sendable (WalkingPlace) async -> Bool = { _ in
      reportIssue("appleMapsClient.openWalkingDirections 미등록")
      return false
    }
  ) {
    walkingDurationHandler = walkingDuration
    openWalkingDirectionsHandler = openWalkingDirections
  }

  public func walkingDuration(
    from origin: LocationCoordinate,
    to place: WalkingPlace
  ) async throws -> WalkingDuration {
    return try await walkingDurationHandler(
      origin,
      place
    )
  }

  public func openWalkingDirections(to place: WalkingPlace) async -> Bool {
    return await openWalkingDirectionsHandler(place)
  }
}
