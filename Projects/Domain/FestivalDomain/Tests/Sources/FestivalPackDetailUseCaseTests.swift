//
//  FestivalPackDetailUseCaseTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCoreNetworkInterface
import FestiCorePackInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalPackDetailUseCaseTests {
  @Test func packDetailReadsDirectionsChecklistAndRules() async throws {
    let service = MutablePackService(packs: [detailPack(version: 12)])
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = DetailCatalogService(items: [.init(id: "fst_a", name: "원더리벳 2026", packVersion: 13)])
    } operation: {
      FestivalPackDetailUseCaseImpl()
    }

    let detail = try #require(try await useCase.packDetail(festivalID: "fst_a"))
    #expect(detail.pack.name == "원더리벳 2026")
    #expect(detail.pack.hasUpdate)
    #expect(detail.directions.lastShuttleAt == "23:40")
    #expect(detail.directions.lastTrainAt == "23:52")
    #expect(detail.directions.shuttle?.links.map(\.label) == ["셔틀 예약하기"])
    #expect(detail.directions.transit?.stationName == "킨텍스역")
    // http 지도 링크와 빈 섹션은 버린다.
    #expect(detail.directions.naverMapURL?.absoluteString == "https://map.naver.com/p/1")
    #expect(detail.directions.kakaoMapURL == nil)
    #expect(detail.directions.parking == nil)
    #expect(detail.directions.memo == "앵콜 전에 움직이세요.")
    #expect(detail.directions.source?.name == "주최측 공지")
    #expect(detail.checklist.map(\.id) == ["ticket", "earplug"])
    #expect(detail.checklist.first?.required == true)
    #expect(detail.rules == ["유리병", "캔"])
    #expect(try await useCase.packDetail(festivalID: "fst_missing") == nil)
  }

  @Test func updatePackSyncsAndRefreshesCatalog() async throws {
    let service = MutablePackService(packs: [detailPack(version: 12)])
    service.onSync = { _ in [detailPack(version: 13)] }
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = DetailCatalogService(items: [.init(id: "fst_a", name: "A", packVersion: 13)])
    } operation: {
      FestivalPackDetailUseCaseImpl()
    }

    let updated = try await useCase.updatePack(festivalID: "fst_a")
    #expect(service.synced.value == ["fst_a"])
    #expect(updated?.pack.packVersion == 13)
    #expect(updated?.pack.hasUpdate == false)
  }

  @Test func updatePackAsksToRetryWhenServerIsBusy() async {
    let service = MutablePackService(packs: [detailPack(version: 12)])
    service.syncResult = .retryAfter(2)
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = DetailCatalogService(items: [])
    } operation: {
      FestivalPackDetailUseCaseImpl()
    }

    await #expect(throws: FestivalPackError.retryLater) { try await useCase.updatePack(festivalID: "fst_a") }
  }

  @Test(arguments: [
    URLError(.notConnectedToInternet) as any Error,
    POSIXError(.ECONNRESET),
    PackSyncError.timeout
  ])
  func updatePackReportsOfflineForTransportFailures(error: any Error) async {
    let service = MutablePackService(packs: [detailPack(version: 12)])
    service.syncError = error
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = DetailCatalogService(items: [])
    } operation: {
      FestivalPackDetailUseCaseImpl()
    }

    await #expect(throws: FestivalPackError.offline) { try await useCase.updatePack(festivalID: "fst_a") }
  }

  @Test func updatePackKeepsOtherSyncErrors() async {
    let service = MutablePackService(packs: [detailPack(version: 12)])
    service.syncError = PackSyncError.invalidMessage
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = DetailCatalogService(items: [])
    } operation: {
      FestivalPackDetailUseCaseImpl()
    }

    await #expect(throws: PackSyncError.invalidMessage) { try await useCase.updatePack(festivalID: "fst_a") }
  }

  @Test func deleteKeepsChecklistAndSettingsInLocalStore() async throws {
    let service = MutablePackService(packs: [detailPack(version: 12)])
    let saved = LockIsolated<[String: FestivalChecklist]>([:])
    let autoDownload = LockIsolated(true)
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = DetailCatalogService(items: [])
      $0.festivalPackLocalStore = FestivalPackLocalStore(
        loadChecklist: { saved.value[$0] ?? FestivalChecklist() },
        saveChecklist: { checklist, id in saved.withValue { $0[id] = checklist } },
        autoDownloadOnWiFi: { autoDownload.value },
        setAutoDownloadOnWiFi: { autoDownload.setValue($0) }
      )
    } operation: {
      FestivalPackDetailUseCaseImpl()
    }

    let checklist = FestivalChecklist(
      checkedIDs: ["ticket"], customItems: [.init(id: "custom-1", label: "선크림")], hiddenIDs: ["earplug"]
    )
    useCase.saveChecklist(checklist, festivalID: "fst_a")
    try await useCase.deletePack(festivalID: "fst_a")
    #expect(service.deleted.value == ["fst_a"])
    #expect(useCase.checklist(festivalID: "fst_a") == checklist)
    useCase.setAutoDownloadOnWiFi(false)
    #expect(!useCase.autoDownloadOnWiFi())
  }

  @Test func localStoreRoundTripsChecklistInUserDefaults() throws {
    let suite = "FestivalPackLocalStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = FestivalPackLocalStore.userDefaults(defaults)

    #expect(store.loadChecklist("fst_a") == FestivalChecklist())
    #expect(store.autoDownloadOnWiFi())
    let checklist = FestivalChecklist(checkedIDs: ["a"], customItems: [.init(id: "c", label: "우비")])
    store.saveChecklist(checklist, "fst_a")
    store.setAutoDownloadOnWiFi(false)
    #expect(store.loadChecklist("fst_a") == checklist)
    #expect(store.loadChecklist("fst_b") == FestivalChecklist())
    #expect(!store.autoDownloadOnWiFi())
  }

  @Test func repositoryRequestsPackChangesWithFromVersion() async throws {
    let body = Data(#"{"code":"SUCCESS","message":"OK","data":{"fromVersion":12,"toVersion":13,"sizeBytes":524288,"changedSets":2,"lastShuttleAt":{"before":"23:40","after":"23:20"},"lastTrainAt":null}}"#.utf8)
    let client = PackChangesClient(body: body)
    let repository = withDependencies {
      $0.networkClient = client
    } operation: {
      FestivalPackRepositoryImpl()
    }

    let changes = try await repository.packChanges(festivalID: "fst_a", fromVersion: 12)
    #expect(changes == FestivalPackChanges(
      fromVersion: 12, toVersion: 13, sizeBytes: 524_288, changedSets: 2,
      lastShuttleAt: .init(before: "23:40", after: "23:20"), lastTrainAt: nil
    ))
    let request = await client.lastRequest
    #expect(request?.path == "api/v1/festivals/fst_a/pack/changes")
    #expect(request?.method == "GET")
    #expect(request?.isPublic == true)
    #expect(request?.query == #"{"from":12}"#)
  }
}

private func detailPack(version: Int) -> CachedFestivalPack {
  let json: [String: Any] = [
    "id": "fst_a",
    "packVersion": version,
    "name": "팩 이름",
    "directions": [
      "lastShuttleAt": "23:40",
      "lastTrainAt": "23:52",
      "shuttle": [
        "body": "대화역 4번 출구 ↔ 킨텍스 셔틀 존",
        "links": [["label": "셔틀 예약하기", "url": "https://example.com/shuttle"], ["label": "", "url": "https://x"]]
      ],
      "transit": ["body": "걸어서 10분", "links": [], "stationName": "킨텍스역", "walkMinutes": 10],
      "parking": ["body": "  ", "links": []],
      "memo": "앵콜 전에 움직이세요.",
      "mapLinks": ["naver": "https://map.naver.com/p/1", "kakao": "http://map.kakao.com"],
      "source": ["name": "주최측 공지", "verifiedAt": "2026-10-16T05:00:00Z"]
    ],
    "checklist": [
      ["id": "ticket", "label": "모바일 티켓", "required": true],
      ["id": "earplug", "label": "귀마개", "required": false],
      ["id": "broken"]
    ],
    "rules": ["유리병", "캔"]
  ]
  let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
  return CachedFestivalPack(festivalID: "fst_a", packVersion: version, etag: "e\(version)", pack: data)
}

private struct DetailCatalogService: FestivalCatalogService {
  let items: [FestivalCatalogItem]

  func cachedFestivals() async throws -> [FestivalCatalogItem] { items }
  func refresh() async throws -> [FestivalCatalogItem] { items }
}

private actor PackChangesClient: FestiCoreNetworkClient {
  struct Request: Sendable {
    let path: String
    let method: String
    let isPublic: Bool
    let query: String?
  }

  let body: Data
  private(set) var lastRequest: Request?

  init(body: Data) {
    self.body = body
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let query = request.parameters.flatMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }
    lastRequest = Request(
      path: request.path,
      method: request.method.rawValue,
      isPublic: request.authorization == .none,
      query: query
    )
    do { return try JSONDecoder().decode(type, from: body) }
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
