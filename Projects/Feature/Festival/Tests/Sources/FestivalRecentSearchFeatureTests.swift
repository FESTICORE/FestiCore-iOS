import ComposableArchitecture
import FestivalDomainInterface
import Testing
@testable import Festival

struct FestivalRecentSearchFeatureTests {
  @Test @MainActor func searchActionsUpdateVisibleKeywordsThroughDependency() async {
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.festivalRecentSearchStore = FestivalRecentSearchStore(
        load: { _ in [] },
        add: { query, _ in [query] },
        remove: { _, _ in [] },
        clear: { _ in }
      )
    }

    await store.send(.view(.recentSearchSubmitted("펜타포트"))) {
      $0.recentSearches = ["펜타포트"]
    }
    await store.send(.view(.recentSearchRemoved("펜타포트"))) {
      $0.recentSearches = []
    }
    await store.send(.view(.recentSearchesCleared))
  }

  @Test @MainActor func switchingAccountsLoadsOnlyThatAccountsSearches() async {
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.festivalRecentSearchStore = FestivalRecentSearchStore(
        load: { userID in userID == "user-a" ? ["A 검색"] : [] },
        add: { _, _ in [] },
        remove: { _, _ in [] },
        clear: { _ in }
      )
    }

    await store.send(.reloadBookmarks(userID: "user-a")) {
      $0.bookedUserID = "user-a"
      $0.recentSearches = ["A 검색"]
    }
    await store.send(.reloadBookmarks(userID: "user-b")) {
      $0.bookedUserID = "user-b"
      $0.recentSearches = []
    }
  }
}
