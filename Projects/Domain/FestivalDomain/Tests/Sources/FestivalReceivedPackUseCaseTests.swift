//
//  FestivalReceivedPackUseCaseTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalReceivedPackUseCaseTests {
  @Test func receivedPacksCombineCacheWithStoredCatalog() async throws {
    let older = Date(timeIntervalSince1970: 100)
    let newer = Date(timeIntervalSince1970: 200)
    let useCase = withDependencies {
      $0.packSyncService = ListPackService(packs: [
        pack("fst_a", version: 12, name: "팩 이름 A", checkedAt: older),
        pack("fst_b", version: 3, name: "팩 이름 B", checkedAt: newer)
      ])
      $0.festivalCatalogService = ReceivedPackCatalogService(
        cached: [.init(id: "fst_a", name: "원더리벳 2026", packVersion: 13)],
        refreshed: []
      )
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    let packs = try await useCase.receivedPacks()
    // 최근에 확인한 팩이 앞에 온다.
    #expect(packs.map(\.id) == ["fst_b", "fst_a"])
    #expect(packs[0].name == "팩 이름 B")
    #expect(packs[0].latestPackVersion == nil)
    #expect(!packs[0].hasUpdate)
    #expect(packs[1].name == "원더리벳 2026")
    #expect(packs[1].packVersion == 12)
    #expect(packs[1].hasUpdate)
    #expect(packs[1].checkedAt == older)
    #expect(packs[1].sizeBytes > 0)
  }

  @Test func refreshUsesServerCatalogForUpdates() async throws {
    let useCase = withDependencies {
      $0.packSyncService = ListPackService(packs: [pack("fst_a", version: 13, name: "A", checkedAt: nil)])
      $0.festivalCatalogService = ReceivedPackCatalogService(
        cached: [.init(id: "fst_a", name: "A", packVersion: 13)],
        refreshed: [.init(id: "fst_a", name: "A", packVersion: 14)]
      )
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    #expect(try await useCase.receivedPacks().first?.hasUpdate == false)
    #expect(try await useCase.refreshReceivedPacks().first?.latestPackVersion == 14)
  }

  @Test func brokenCatalogCacheStillListsPacks() async throws {
    let useCase = withDependencies {
      $0.packSyncService = ListPackService(packs: [pack("fst_a", version: 1, name: nil, checkedAt: nil)])
      $0.festivalCatalogService = ReceivedPackCatalogService(cached: nil, refreshed: [])
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    let packs = try await useCase.receivedPacks()
    #expect(packs.map(\.name) == ["fst_a"])
  }

  @Test func refreshDownloadsUpdatesOnWiFiWhenAutoDownloadIsOn() async throws {
    let service = MutablePackService(packs: [pack("fst_a", version: 1, name: "A", checkedAt: nil)])
    service.onSync = { id in [self.pack(id, version: 2, name: "A", checkedAt: nil)] }
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = ReceivedPackCatalogService(
        cached: [], refreshed: [.init(id: "fst_a", name: "A", packVersion: 2)]
      )
      $0.festivalPackLocalStore.autoDownloadOnWiFi = { true }
      $0.festivalWiFiStatus = .init(isOnWiFi: { true })
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    let packs = try await useCase.refreshReceivedPacks()
    #expect(service.synced.value == ["fst_a"])
    #expect(packs.first?.packVersion == 2)
    #expect(packs.first?.hasUpdate == false)
  }

  @Test func refreshMarksPacksThatFailedToDownload() async throws {
    let service = MutablePackService(packs: [pack("fst_a", version: 1, name: "A", checkedAt: nil)])
    service.syncError = URLError(.notConnectedToInternet)
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = ReceivedPackCatalogService(
        cached: [], refreshed: [.init(id: "fst_a", name: "A", packVersion: 2)]
      )
      $0.festivalPackLocalStore.autoDownloadOnWiFi = { true }
      $0.festivalWiFiStatus = .init(isOnWiFi: { true })
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    let packs = try await useCase.refreshReceivedPacks()
    #expect(service.synced.value == ["fst_a"])
    #expect(packs.first?.hasUpdate == true)
    #expect(packs.first?.autoUpdateFailed == true)
  }

  @Test func refreshPropagatesCancellationDuringAutoDownload() async throws {
    let service = MutablePackService(packs: [
      pack("fst_a", version: 1, name: "A", checkedAt: nil),
      pack("fst_b", version: 1, name: "B", checkedAt: nil)
    ])
    service.syncError = CancellationError()
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = ReceivedPackCatalogService(
        cached: [], refreshed: [
          .init(id: "fst_a", name: "A", packVersion: 2), .init(id: "fst_b", name: "B", packVersion: 2)
        ]
      )
      $0.festivalPackLocalStore.autoDownloadOnWiFi = { true }
      $0.festivalWiFiStatus = .init(isOnWiFi: { true })
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    await #expect(throws: CancellationError.self) { try await useCase.refreshReceivedPacks() }
    #expect(service.synced.value.count == 1)
  }

  @Test(arguments: [(true, false), (false, true)])
  func refreshKeepsUpdatesOffWiFiOrWhenAutoDownloadIsOff(autoDownload: Bool, onWiFi: Bool) async throws {
    let service = MutablePackService(packs: [pack("fst_a", version: 1, name: "A", checkedAt: nil)])
    let useCase = withDependencies {
      $0.packSyncService = service
      $0.festivalCatalogService = ReceivedPackCatalogService(
        cached: [], refreshed: [.init(id: "fst_a", name: "A", packVersion: 2)]
      )
      $0.festivalPackLocalStore.autoDownloadOnWiFi = { autoDownload }
      $0.festivalWiFiStatus = .init(isOnWiFi: { onWiFi })
    } operation: {
      FestivalReceivedPackUseCaseImpl()
    }

    #expect(try await useCase.refreshReceivedPacks().first?.hasUpdate == true)
    #expect(service.synced.value.isEmpty)
  }

  func pack(_ id: String, version: Int, name: String?, checkedAt: Date?) -> CachedFestivalPack {
    var json: [String: Any] = ["id": id, "packVersion": version]
    json["name"] = name
    let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    return CachedFestivalPack(festivalID: id, packVersion: version, etag: "e", pack: data, checkedAt: checkedAt)
  }
}

private struct ReceivedPackCatalogError: Error {}

private struct ReceivedPackCatalogService: FestivalCatalogService {
  let cached: [FestivalCatalogItem]?
  let refreshed: [FestivalCatalogItem]

  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    guard let cached else { throw ReceivedPackCatalogError() }
    return cached
  }

  func refresh() async throws -> [FestivalCatalogItem] { refreshed }
}

private struct ListPackService: PackSyncService {
  let packs: [CachedFestivalPack]

  func cachedPack(for festivalID: String) async throws -> CachedFestivalPack? {
    packs.first { $0.festivalID == festivalID }
  }

  func cachedPacks() async throws -> [CachedFestivalPack] { packs }
  func sync(for _: String) async throws -> PackSyncResult { .reconnecting }
  func deletePack(for _: String) async throws {}
  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}

final class MutablePackService: PackSyncService, @unchecked Sendable {
  let packs: LockIsolated<[CachedFestivalPack]>
  let synced = LockIsolated<[String]>([])
  let deleted = LockIsolated<[String]>([])
  var onSync: (@Sendable (String) -> [CachedFestivalPack])?
  var syncResult: PackSyncResult?
  var syncError: (any Error)?

  init(packs: [CachedFestivalPack]) {
    self.packs = LockIsolated(packs)
  }

  func cachedPack(for festivalID: String) async throws -> CachedFestivalPack? {
    packs.value.first { $0.festivalID == festivalID }
  }

  func cachedPacks() async throws -> [CachedFestivalPack] { packs.value }

  func sync(for festivalID: String) async throws -> PackSyncResult {
    synced.withValue { $0.append(festivalID) }
    if let syncError { throw syncError }
    if let onSync { packs.setValue(onSync(festivalID)) }
    if let syncResult { return syncResult }
    guard let pack = packs.value.first(where: { $0.festivalID == festivalID }) else { return .reconnecting }
    return .updated(pack)
  }

  func deletePack(for festivalID: String) async throws {
    deleted.withValue { $0.append(festivalID) }
    packs.withValue { $0.removeAll { $0.festivalID == festivalID } }
  }

  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}
