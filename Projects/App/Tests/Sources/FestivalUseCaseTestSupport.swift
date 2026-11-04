import ComposableArchitecture
import FestivalDomainInterface
import Foundation

extension DependencyValues {
  /// 홈 탭의 Festival 화면이 테스트의 서비스·스토어 대역을 쓰도록 UseCase를 연결한다.
  /// 테스트마다 직접 부르고, 따로 넘기지 않은 서비스는 각 서비스의 테스트 기본값을 쓴다.
  /// 코디네이터 테스트가 거치는 예약·최근 검색과 라이브 보드·내 일정만 연결한다.
  mutating func useServiceBackedFestivalUseCases() {
    festivalLibraryUseCase = ServiceBackedLibraryUseCase()
    festivalLiveBoardUseCase = ServiceBackedLiveBoardUseCase()
    festivalScheduleUseCase = ServiceBackedScheduleUseCase()
    festivalGuideVisibilityUseCase = MockFestivalGuideVisibilityUseCase(
      isHidden: { _ in false },
      hide: { _ in }
    )
    festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(activities: { [] })
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

  func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }
}

private struct ServiceBackedScheduleUseCase: FestivalScheduleUseCaseInterface {
  @Dependency(\.festivalScheduleService) var scheduleService

  func mySchedule(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.fetch(festivalID: festivalID)
  }
  func saveMySchedule(
    festivalID: String, setIDs: [String], clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    try await scheduleService.replace(festivalID: festivalID, setIDs: setIDs, clientAt: clientAt)
  }
}
