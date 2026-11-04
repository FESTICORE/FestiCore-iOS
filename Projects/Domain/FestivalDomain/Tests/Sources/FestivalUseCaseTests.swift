//
//  FestivalUseCaseTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalUseCaseTests {
  @Test func catalogUseCaseReadsCatalogAndRemembersSelection() async throws {
    let saved = LockIsolated<String?>(nil)
    let useCase = withDependencies {
      $0.festivalCatalogRepository = StubCatalogRepository(
        cached: [.init(id: "cached", name: "캐시", packVersion: 1)],
        refreshed: [.init(id: "fresh", name: "새 목록", packVersion: 1)]
      )
      $0.festivalSelectionStore = .init(load: { "saved" }, save: { saved.setValue($0) })
    } operation: {
      FestivalCatalogUseCaseImpl()
    }

    #expect(try await useCase.cachedFestivals().map(\.id) == ["cached"])
    #expect(try await useCase.refreshFestivals().map(\.id) == ["fresh"])
    #expect(useCase.savedFestivalID() == "saved")
    useCase.saveSelectedFestivalID("fresh")
    #expect(saved.value == "fresh")
  }

  @Test func packUseCaseForwardsCachedPacksAndUpdates() async throws {
    let pack = CachedFestivalPack(festivalID: "fst", packVersion: 2, etag: "e", pack: Data())
    let useCase = withDependencies {
      $0.festivalPackSyncRepository = StubPackRepository(pack: pack)
    } operation: {
      FestivalPackUseCaseImpl()
    }

    #expect(try await useCase.cachedPacks() == [pack])
    var results: [PackSyncResult] = []
    for try await result in useCase.packUpdates(for: "fst") {
      results.append(result)
    }
    #expect(results == [.updated(pack)])
    var downloadEvents: [PackDownloadEvent] = []
    for try await event in useCase.downloadPack(for: "fst") {
      downloadEvents.append(event)
    }
    #expect(downloadEvents == [.finished(.updated(pack))])
  }

  @Test func catalogRepositoryForwardsServiceCalls() async throws {
    let repository = withDependencies {
      $0.festivalCatalogService = StubCatalogService(
        cached: [.init(
          id: "cached",
          name: "캐시",
          packVersion: 1
        )],
        refreshed: [.init(
          id: "fresh",
          name: "새 목록",
          packVersion: 1
        )]
      )
    } operation: {
      FestivalCatalogRepositoryImpl()
    }

    #expect(try await repository.cachedFestivals().map(\.id) == ["cached"])
    #expect(try await repository.refreshFestivals().map(\.id) == ["fresh"])
  }

  @Test func packRepositoryForwardsCacheUpdatesAndDownload() async throws {
    let pack = CachedFestivalPack(
      festivalID: "fst",
      packVersion: 2,
      etag: "e",
      pack: Data()
    )
    let repository = withDependencies {
      $0.packSyncService = StubPackService(pack: pack)
    } operation: {
      FestivalPackSyncRepositoryImpl()
    }

    #expect(try await repository.cachedPacks() == [pack])
    var updates: [PackSyncResult] = []
    for try await result in repository.packUpdates(for: "fst") { updates.append(result) }
    #expect(updates == [.updated(pack)])
    var downloads: [PackDownloadEvent] = []
    for try await event in repository.downloadPack(for: "fst") { downloads.append(event) }
    #expect(downloads == [.finished(.updated(pack))])
  }

  @Test func liveBoardUseCaseLoadsBoard() async throws {
    let useCase = withDependencies {
      $0.festivalLiveBoardService = StubLiveBoardService()
    } operation: {
      FestivalLiveBoardUseCaseImpl()
    }

    #expect(try await useCase.liveBoard(for: "fst").festivalID == "fst")
  }

  @Test func libraryUseCaseUsesAccountScopedStores() {
    let cleared = LockIsolated<[String?]>([])
    let useCase = withDependencies {
      $0.festivalBookedStore = .init(load: { ["booked_\($0)"] }, save: { _, _ in })
      $0.festivalRecentSearchStore = .init(
        load: { [$0 ?? "anonymous"] },
        add: { query, userID in [query, userID ?? "anonymous"] },
        remove: { _, userID in [userID ?? "anonymous"] },
        clear: { userID in cleared.withValue { $0.append(userID) } }
      )
    } operation: {
      FestivalLibraryUseCaseImpl()
    }

    #expect(useCase.bookedFestivalIDs(for: "user") == ["booked_user"])
    #expect(useCase.recentSearches(for: nil) == ["anonymous"])
    #expect(useCase.addRecentSearch("펜타", for: "user") == ["펜타", "user"])
    #expect(useCase.removeRecentSearch("펜타", for: "user") == ["user"])
    useCase.clearRecentSearches(for: "user")
    #expect(cleared.value == ["user"])
  }

  @Test func flagUseCaseLoadsBoardAndPassesFollowErrors() async throws {
    let useCase = withDependencies {
      $0.festivalLiveBoardService = StubLiveBoardService()
      $0.festivalFlagFollowService = StubFollowService()
    } operation: {
      FestivalFlagUseCaseImpl()
    }

    #expect(try await useCase.liveBoard(for: "fst").festivalID == "fst")
    #expect(try await useCase.setFollowing(true, flagID: "flag").isFollowing)
    await #expect(throws: FestivalFlagFollowError.loginRequired) {
      try await useCase.setFollowing(false, flagID: "flag")
    }
  }

  @Test func liveActivityUseCaseForwardsEveryCall() async throws {
    let calls = LockIsolated<[String]>([])
    let start = Date(timeIntervalSince1970: 100)
    let end = Date(timeIntervalSince1970: 200)
    let useCase = withDependencies {
      $0.festivalLiveActivityClient = .init(
        activities: {
          [.init(
            id: "a",
            festivalID: "fst",
            phase: .upcoming,
            startDate: start,
            endDate: end
          )]
        },
        changes: { AsyncStream { $0.finish() } },
        start: { id, name, _, _, phase in
          calls.withValue { $0.append("start \(id) \(name) \(phase)") }
          return "activity"
        },
        update: { id, phase, _, _, _, _ in calls.withValue { $0.append("update \(id) \(phase)") } },
        finish: { id, _ in calls.withValue { $0.append("finish \(id)") } },
        end: { id in calls.withValue { $0.append("end \(id)") } }
      )
    } operation: {
      FestivalLiveActivityUseCaseImpl()
    }

    #expect(await useCase.activities().map(\.id) == ["a"])
    #expect(
      try await useCase.start(
        festivalID: "fst",
        festivalName: "축제",
        startDate: start,
        endDate: end,
        phase: .upcoming
      ) == "activity")
    await useCase.update(
      activityID: "activity",
      phase: .ongoing,
      startDate: start,
      endDate: end,
      pack: nil,
      savedSetIDs: []
    )
    await useCase.finish(activityID: "activity", startDate: start)
    await useCase.end(activityID: "activity")
    #expect(
      calls.value == [
        "start fst 축제 upcoming", "update activity ongoing", "finish activity", "end activity",
      ])
  }

  @Test func imageUseCaseKeepsHTTPSOnlyAndForwardsPrefetch() async {
    let prefetched = LockIsolated<[[URL]]>([])
    let image = URL(string: "https://example.com/a.jpg")!
    let useCase = withDependencies {
      $0.festivalCatalogService = StubCatalogService(cached: [], refreshed: [])
      $0.festivalImagePrefetchClient = .init(
        start: { urls in prefetched.withValue { $0.append(urls) } },
        stop: { prefetched.withValue { $0.append([]) } }
      )
    } operation: {
      FestivalImageUseCaseImpl()
    }

    #expect(useCase.imageURL(for: image.absoluteString) == image)
    #expect(useCase.imageURL(for: "http://example.com/a.jpg") == nil)
    await useCase.startPrefetch([image])
    await useCase.stopPrefetch()
    #expect(prefetched.value == [[image], []])
  }

  @Test func missingUseCasesRecordIssues() async {
    await withKnownIssue("festivalCatalogUseCase 미등록") {
      _ = try? await FestivalCatalogUseCaseDependency.testValue.refreshFestivals()
    }
    await withKnownIssue("festivalPackUseCase 미등록") {
      _ = try? await FestivalPackUseCaseDependency.testValue.cachedPacks()
    }
    await withKnownIssue("festivalLiveBoardUseCase 미등록") {
      _ = try? await FestivalLiveBoardUseCaseDependency.testValue.liveBoard(for: "fst")
    }
    withKnownIssue("festivalLibraryUseCase 미등록") {
      _ = FestivalLibraryUseCaseDependency.testValue.recentSearches(for: nil)
    }
    await withKnownIssue("festivalFlagUseCase 미등록") {
      _ = try? await FestivalFlagUseCaseDependency.testValue.setFollowing(true, flagID: "flag")
    }
    await withKnownIssue("festivalLiveActivityUseCase 미등록") {
      _ = await FestivalLiveActivityUseCaseDependency.testValue.activities()
    }
    withKnownIssue("festivalImageUseCase 미등록") {
      _ = FestivalImageUseCaseDependency.testValue.imageURL(for: nil)
    }
  }
}

private struct StubCatalogRepository: FestivalCatalogRepositoryInterface {
  let cached: [FestivalCatalogItem]
  let refreshed: [FestivalCatalogItem]

  func cachedFestivals() async throws -> [FestivalCatalogItem] { return cached }
  func refreshFestivals() async throws -> [FestivalCatalogItem] { return refreshed }
}

private struct StubCatalogService: FestivalCatalogService {
  let cached: [FestivalCatalogItem]
  let refreshed: [FestivalCatalogItem]

  func cachedFestivals() async throws -> [FestivalCatalogItem] { cached }
  func refresh() async throws -> [FestivalCatalogItem] { refreshed }
}

private struct StubPackRepository: FestivalPackSyncRepositoryInterface {
  let pack: CachedFestivalPack

  func cachedPacks() async throws -> [CachedFestivalPack] { return [pack] }
  func packUpdates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    return AsyncThrowingStream {
      $0.yield(.updated(pack))
      $0.finish()
    }
  }
  func downloadPack(for _: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    return AsyncThrowingStream {
      $0.yield(.finished(.updated(pack)))
      $0.finish()
    }
  }
}

private struct StubPackService: PackSyncService {
  let pack: CachedFestivalPack

  func cachedPack(for _: String) async throws -> CachedFestivalPack? { pack }
  func cachedPacks() async throws -> [CachedFestivalPack] { [pack] }
  func sync(for _: String) async throws -> PackSyncResult { .updated(pack) }
  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream {
      $0.yield(.updated(pack))
      $0.finish()
    }
  }
  func download(for _: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    return AsyncThrowingStream {
      $0.yield(.finished(.updated(pack)))
      $0.finish()
    }
  }
}

private struct StubLiveBoardService: FestivalLiveBoardService {
  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    .init(festivalID: festivalID, activeFlags: [], followedFlags: [], crew: nil)
  }
}

private struct StubFollowService: FestivalFlagFollowService {
  func setFollowing(
    _ following: Bool,
    flagID: String
  ) async throws(FestivalFlagFollowError)
    -> FestivalFlagFollowResult
  {
    guard following else { throw .loginRequired }
    return .init(flagID: flagID, isFollowing: true, followerCount: 1)
  }
}
