//
//  NearestPlaceTests.swift
//  FestiCoreLocationTests
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreLocationInterface
import Testing
@testable import FestiCoreLocation

@Suite("이름 검색 목적지 고르기")
struct NearestPlaceTests {
  /// 서현역 근처 축제 장소
  private let venue = LocationCoordinate(
    latitude: 37.3850,
    longitude: 127.1230
  )
  /// 장소에서 약 400m
  private let nearStation = LocationCoordinate(
    latitude: 37.3836,
    longitude: 127.1268
  )
  /// 장소에서 약 1.5km
  private let fartherStation = LocationCoordinate(
    latitude: 37.3990,
    longitude: 127.1200
  )
  /// 같은 이름의 다른 도시 역(부산)
  private let otherCityStation = LocationCoordinate(
    latitude: 35.1151,
    longitude: 129.0422
  )

  @Test("축제 장소에서 가장 가까운 후보를 고른다")
  func picksNearestCandidate() {
    let match = NearestPlace.match(
      [
        fartherStation,
        nearStation,
      ],
      near: venue,
      within: 5_000
    )
    #expect(match == nearStation)
  }

  @Test("검색 반경보다 먼 같은 이름의 장소는 목적지로 쓰지 않는다")
  func dropsCandidatesOutsideRadius() {
    let match = NearestPlace.match(
      [otherCityStation],
      near: venue,
      within: 5_000
    )
    #expect(match == nil)
  }

  @Test("기준 위치가 잘못됐으면 어떤 후보도 목적지로 쓰지 않는다")
  func refusesInvalidCenter() {
    let match = NearestPlace.match(
      [nearStation],
      near: LocationCoordinate(
        latitude: .nan,
        longitude: 127
      ),
      within: 5_000
    )
    #expect(match == nil)
  }

  @Test("범위를 벗어난 좌표 후보는 버린다")
  func ignoresInvalidCoordinates() {
    let invalid = LocationCoordinate(
      latitude: 120,
      longitude: 127
    )
    let match = NearestPlace.match(
      [
        invalid,
        nearStation,
      ],
      near: venue,
      within: 5_000
    )
    #expect(match == nearStation)
  }
}
