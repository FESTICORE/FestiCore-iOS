//
//  LocationAuthorizationTests.swift
//  FestiCoreLocationTests
//
//  Created by FestiCore on 11/8/26.
//

import CoreLocation
import FestiCoreLocationInterface
import Testing
@testable import FestiCoreLocation

@Suite("위치 권한 상태")
struct LocationAuthorizationTests {
  @Test(
    "CoreLocation 권한 값을 앱 권한 상태로 바꾼다",
    arguments: [
      (CLAuthorizationStatus.notDetermined, LocationAuthorization.notDetermined),
      (.restricted, .restricted),
      (.denied, .denied),
      (.authorizedWhenInUse, .authorized),
      (.authorizedAlways, .authorized),
    ]
  )
  func mapsCoreLocationStatus(
    status: CLAuthorizationStatus,
    expected: LocationAuthorization
  ) {
    #expect(LocationAuthorization(status) == expected)
  }

  @Test("넘기지 않은 권한 호출은 테스트 이슈로 남기고 위치를 쓰지 않는 쪽으로 답한다")
  func unregisteredMockRefusesLocation() async {
    let client = MockLocationClient()

    await withKnownIssue {
      #expect(await client.authorization() == .denied)
    }
    await withKnownIssue {
      #expect(await client.requestWhenInUseAuthorization() == .denied)
    }
    await withKnownIssue {
      await #expect(throws: LocationClientError.notRegistered) {
        try await client.currentLocation()
      }
    }
  }
}
