//
//  FestivalZoneMapUseCaseTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies
import FestiCoreNetworkInterface
import FestiCorePackInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalZoneMapUseCaseTests {
  @Test func cachedMapReadsZoneAreasStageHeadersAndNowPlaying() async throws {
    let useCase = withDependencies {
      $0.packSyncService = MutablePackService(packs: [zoneMapPack()])
    } operation: {
      return FestivalZoneMapUseCaseImpl()
    }
    let now = try Date(
      "2026-11-20T13:30:00+09:00",
      strategy: .iso8601
    )

    let map = try #require(try await useCase.cachedMap(
      festivalID: "fst_a",
      now: now
    ))

    #expect(map.version == "zm-3f2a9c1d0b7e")
    #expect(map.aspect == 0.655)
    #expect(map.flagsEnabled == false)
    #expect(map.hasLayout)
    // order 순서로 정렬하고 형식이 틀린 존은 버린다.
    #expect(map.zones.map(\.id) == ["zon_a", "zon_b"])
    #expect(map.zones[0].area == FestivalZoneMap.Area(
      x: 0.02,
      y: 0.07,
      width: 0.44,
      height: 0.16
    ))
    #expect(map.zones[0].kind == "무대 앞")
    #expect(map.zones[1].area == nil)
    #expect(map.zones[1].landmark == "TENT 무대")
    // 팩에 없는 무대의 머리글은 버린다.
    #expect(map.stageHeaders.map(\.name) == ["RIVET STAGE", "WONDER STAGE"])
    #expect(map.stageHeaders[0].nowPlaying == "터치드")
    #expect(map.stageHeaders[1].nowPlaying == nil)
    #expect(try await useCase.cachedMap(
      festivalID: "fst_missing",
      now: now
    ) == nil)
  }

  @Test func mapWithoutZoneAreasShowsList() {
    let map = FestivalZoneMap(
      festivalID: "fst_a",
      version: "zm-1",
      imageURL: nil,
      aspect: nil,
      flagsEnabled: true,
      zones: [.init(
        id: "zon_a",
        name: "A",
        kind: nil,
        area: nil,
        landmark: nil
      )],
      stageHeaders: []
    )
    #expect(map.hasLayout == false)
  }

  @Test func isMapChangedComparesServerMapVersion() async throws {
    let body = #"{"code":"SUCCESS","data":{"packVersion":9,"packUpdatedAt":"2026-11-08T00:00:00Z","etag":"\"cdm7-v9\"","mapVersion":"zm-new"}}"#
    let client = PackVersionClient(body: Data(body.utf8))
    let repository = withDependencies {
      $0.networkClient = client
    } operation: {
      return FestivalZoneMapRepositoryImpl()
    }
    let useCase = withDependencies {
      $0.festivalZoneMapRepository = repository
    } operation: {
      return FestivalZoneMapUseCaseImpl()
    }
    let map = FestivalZoneMap(
      festivalID: "fst_a",
      version: "zm-old",
      imageURL: nil,
      aspect: 0.6,
      flagsEnabled: true,
      zones: [],
      stageHeaders: []
    )

    #expect(try await useCase.isMapChanged(map))
    let request = try #require(await client.lastRequest)
    #expect(request.path == "api/v1/festivals/fst_a/pack/version")
    #expect(request.method == "GET")
    #expect(request.isPublic)
  }
}

private func zoneMapPack() -> CachedFestivalPack {
  let json: [String: Any] = [
    "id": "fst_a",
    "packVersion": 9,
    "flagsEnabled": false,
    "mapImageUrl": NSNull(),
    "mapAspect": 0.655,
    "mapVersion": "zm-3f2a9c1d0b7e",
    "stages": [
      ["id": "stg_rivet", "name": "RIVET STAGE", "order": 1],
      ["id": "stg_wonder", "name": "WONDER STAGE", "order": 2],
    ],
    "mapStages": [
      ["stageId": "stg_rivet", "x": 0.0254, "y": 0.02, "w": 0.4427],
      ["stageId": "stg_wonder", "x": 0.5318, "y": 0.02, "w": 0.4427],
      ["stageId": "stg_missing", "x": 0.1, "y": 0.1, "w": 0.1],
    ],
    "zones": [
      ["id": "zon_b", "name": "TENT 앞", "x": 0.7, "y": 0.5, "order": 2, "area": NSNull(), "landmark": "TENT 무대"],
      ["id": "zon_a", "name": "리벳 스테이지 앞 왼쪽", "kind": "무대 앞", "x": 0.24, "y": 0.15, "order": 1, "area": ["x": 0.02, "y": 0.07, "w": 0.44, "h": 0.16]],
      ["name": "ID 없는 존"],
    ],
    "sets": [
      ["stageId": "stg_rivet", "artist": "터치드", "startsAt": "2026-11-20T13:00:00+09:00", "endsAt": "2026-11-20T14:00:00+09:00"],
      ["stageId": "stg_wonder", "artist": "LUCY", "startsAt": "2026-11-20T14:00:00+09:00", "endsAt": "2026-11-20T15:00:00+09:00"],
    ],
  ]
  return CachedFestivalPack(
    festivalID: "fst_a",
    packVersion: 9,
    etag: "\"cdm7-v9\"",
    pack: (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
  )
}

private actor PackVersionClient: FestiCoreNetworkClient {
  struct Request: Sendable {
    let path: String
    let method: String
    let isPublic: Bool
  }

  let body: Data
  private(set) var lastRequest: Request?

  init(body: Data) {
    self.body = body
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    lastRequest = Request(
      path: request.path,
      method: request.method.rawValue,
      isPublic: request.authorization == .none
    )
    do {
      return try JSONDecoder().decode(
        type,
        from: body
      )
    }
    catch { throw .decoding(.failed(error)) }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func sendResponse<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    throw .request(.invalidURL)
  }
}
