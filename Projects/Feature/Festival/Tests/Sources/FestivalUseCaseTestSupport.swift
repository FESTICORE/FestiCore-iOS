import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation

extension DependencyValues {
  /// 서비스·스토어 대역으로 화면을 검증하는 테스트가 UseCase를 그 대역에 연결한다.
  /// 테스트마다 직접 부르고, 따로 넘기지 않은 서비스는 각 서비스의 테스트 기본값을 쓴다.
  mutating func useServiceBackedFestivalUseCases() {
    festivalCatalogUseCase = ServiceBackedCatalogUseCase()
    festivalPackUseCase = ServiceBackedPackUseCase()
    festivalLibraryUseCase = ServiceBackedLibraryUseCase()
    festivalLiveBoardUseCase = ServiceBackedLiveBoardUseCase()
    festivalImageUseCase = ServiceBackedImageUseCase()
    festivalLiveActivityUseCase = ServiceBackedLiveActivityUseCase()
  }
}

private struct ServiceBackedCatalogUseCase: FestivalCatalogUseCaseInterface {
  @Dependency(\.festivalCatalogService) var catalogService
  @Dependency(\.festivalSelectionStore) var selectionStore

  func cachedFestivals() async throws -> [FestivalCatalogItem] { try await catalogService.cachedFestivals() }
  func refreshFestivals() async throws -> [FestivalCatalogItem] { try await catalogService.refresh() }
  func savedFestivalID() -> String? { selectionStore.load() }
  func saveSelectedFestivalID(_ festivalID: String?) { selectionStore.save(festivalID) }
}

private struct ServiceBackedPackUseCase: FestivalPackUseCaseInterface {
  @Dependency(\.packSyncService) var packService

  func cachedPacks() async throws -> [CachedFestivalPack] { try await packService.cachedPacks() }
  func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    packService.updates(for: festivalID)
  }
}

private struct ServiceBackedLibraryUseCase: FestivalLibraryUseCaseInterface {
  @Dependency(\.festivalBookedStore) var bookedStore
  @Dependency(\.festivalRecentSearchStore) var recentSearchStore

  func bookedFestivalIDs(for userID: String) -> Set<String> { bookedStore.load(for: userID) }
  func recentSearches(for userID: String?) -> [String] { recentSearchStore.load(for: userID) }
  func addRecentSearch(_ query: String, for userID: String?) -> [String] { recentSearchStore.add(query, for: userID) }
  func removeRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.remove(query, for: userID)
  }
  func clearRecentSearches(for userID: String?) { recentSearchStore.clear(for: userID) }
}

private struct ServiceBackedLiveBoardUseCase: FestivalLiveBoardUseCaseInterface {
  @Dependency(\.festivalLiveBoardService) var liveBoardService
  @Dependency(\.festivalScheduleService) var scheduleService

  func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }
  func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.fetch(festivalID: festivalID)
  }
}

private struct ServiceBackedImageUseCase: FestivalImageUseCaseInterface {
  @Dependency(\.festivalCatalogService) var catalogService
  @Dependency(\.festivalImagePrefetchClient) var prefetchClient

  func imageURL(for value: String?) -> URL? { catalogService.imageURL(for: value) }
  func startPrefetch(_ urls: [URL]) async { await prefetchClient.start(urls) }
  func stopPrefetch() async { await prefetchClient.stop() }
}

private struct ServiceBackedLiveActivityUseCase: FestivalLiveActivityUseCaseInterface {
  @Dependency(\.festivalLiveActivityClient) var client

  func activities() async -> [FestivalLiveActivityRecord] { await client.activities() }
  func activityChanges() -> AsyncStream<Void> { client.changes() }
  func start(
    festivalID: String, festivalName: String, startDate: Date, endDate: Date, phase: FestivalLiveActivityPhase
  ) async throws -> String {
    try await client.start(festivalID, festivalName, startDate, endDate, phase)
  }
  func update(activityID: String, phase: FestivalLiveActivityPhase, startDate: Date, endDate: Date) async {
    await client.update(activityID, phase, startDate, endDate)
  }
  func finish(activityID: String, startDate: Date) async { await client.finish(activityID, startDate) }
  func end(activityID: String) async { await client.end(activityID) }
}
