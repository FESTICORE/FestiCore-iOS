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

  private func pack(_ id: String, version: Int, name: String?, checkedAt: Date?) -> CachedFestivalPack {
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
  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}
