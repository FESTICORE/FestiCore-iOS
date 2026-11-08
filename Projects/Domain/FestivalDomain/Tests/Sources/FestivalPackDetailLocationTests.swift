//
//  FestivalPackDetailLocationTests.swift
//  FestivalDomainTests
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

/// 귀가 도보 시간 계산에 쓰는 축제 장소·역·정류장 좌표를 팩에서 읽는다.
struct FestivalPackDetailLocationTests {
  @Test("축제 장소 좌표, 셔틀 정류장 이름과 역·정류장 좌표를 읽는다")
  func readsVenueAndStationLocations() async throws {
    let detail = try await packDetail(directions: [
      "location": [
        "latitude": 37.3850,
        "longitude": 127.1230,
        "label": "원더리벳 공연장",
      ],
      "shuttle": [
        "body": "정문 앞에서 출발",
        "links": [],
        "stopName": "정문 셔틀 정류장",
        "location": ["latitude": 37.3861, "longitude": 127.1241],
      ],
      "transit": [
        "links": [],
        "stationName": "서현역",
        "walkMinutes": 12,
        "location": ["latitude": 37.3836, "longitude": 127.1268],
      ],
    ])

    #expect(detail.directions.venueLocation == .init(
      latitude: 37.3850,
      longitude: 127.1230
    ))
    #expect(detail.directions.shuttle?.stopName == "정문 셔틀 정류장")
    #expect(detail.directions.shuttle?.stationName == nil)
    #expect(detail.directions.shuttle?.location == .init(
      latitude: 37.3861,
      longitude: 127.1241
    ))
    #expect(detail.directions.transit?.stationName == "서현역")
    #expect(detail.directions.transit?.walkMinutes == 12)
    #expect(detail.directions.transit?.location == .init(
      latitude: 37.3836,
      longitude: 127.1268
    ))
  }

  @Test("형식이 다르거나 범위를 벗어난 좌표는 버리고 나머지 가는 길은 남긴다")
  func dropsMalformedLocationsOnly() async throws {
    let detail = try await packDetail(directions: [
      "lastTrainAt": "23:52",
      "location": "올림픽공원",
      "shuttle": [
        "body": "정문 앞에서 출발",
        "links": [],
        "stopName": "정문 셔틀 정류장",
        "location": ["latitude": "37.38", "longitude": 127.12],
      ],
      "transit": [
        "links": [],
        "stationName": "서현역",
        "location": ["latitude": 137.0, "longitude": 127.1268],
      ],
    ])

    #expect(detail.directions.lastTrainAt == "23:52")
    #expect(detail.directions.venueLocation == nil)
    #expect(detail.directions.shuttle?.stopName == "정문 셔틀 정류장")
    #expect(detail.directions.shuttle?.location == nil)
    #expect(detail.directions.transit?.stationName == "서현역")
    #expect(detail.directions.transit?.location == nil)
  }

  private func packDetail(directions: [String: Any]) async throws -> FestivalPackDetail {
    let json: [String: Any] = [
      "id": "fst_a",
      "packVersion": 1,
      "name": "팩 이름",
      "directions": directions,
    ]
    let data = try JSONSerialization.data(withJSONObject: json)
    let service = MutablePackService(packs: [CachedFestivalPack(
      festivalID: "fst_a",
      packVersion: 1,
      etag: "e1",
      pack: data
    )])
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = LocationCatalogService()
    } operation: {
      return FestivalPackDetailUseCaseImpl()
    }
    return try #require(try await useCase.packDetail(festivalID: "fst_a"))
  }
}

private struct LocationCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    return [.init(
      id: "fst_a",
      name: "원더리벳 2026",
      packVersion: 1
    )]
  }

  func refresh() async throws -> [FestivalCatalogItem] {
    return try await cachedFestivals()
  }
}
