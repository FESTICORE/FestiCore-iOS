import ComposableArchitecture
import FestivalDomainInterface
import Testing
@testable import Festival

struct FestivalRecentSearchFeatureTests {
  @Test @MainActor func searchStartsWithOnlyRecentKeywordsAndClosesWithoutChangingFilter() async {
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.view(.searchOpened)) {
      $0.listInteraction.isSearching = true
    }
    #expect(store.state.listInteraction.trimmedQuery.isEmpty)

    await store.send(.view(.searchQueryChanged(" 펜타포트 "))) {
      $0.listInteraction.query = " 펜타포트 "
    }
    #expect(store.state.listInteraction.trimmedQuery == "펜타포트")

    await store.send(.view(.listFilterChanged(.booked))) {
      $0.listInteraction.selectedFilter = .booked
    }
    await store.send(.view(.searchClosed)) {
      $0.listInteraction.isSearching = false
      $0.listInteraction.query = ""
    }
    #expect(store.state.listInteraction.selectedFilter == .booked)
  }

  @Test @MainActor func accountChangeResetsSearchAndSelectedFilter() async {
    var state = FestivalFeature.State()
    state.listInteraction = FestivalListInteractionState(
      selectedFilter: .booked,
      isSearching: true,
      query: "기존 검색"
    )
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.festivalRecentSearchStore = FestivalRecentSearchStore(
        load: { _ in [] },
        add: { _, _ in [] },
        remove: { _, _ in [] },
        clear: { _ in }
      )
    }

    await store.send(.view(.reloadBookmarks(userID: "new-user"))) {
      $0.listInteraction.reset()
      $0.bookedUserID = "new-user"
    }
  }

  @Test @MainActor func searchActionsUpdateVisibleKeywordsThroughDependency() async {
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
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
      $0.useServiceBackedFestivalUseCases()
      $0.festivalRecentSearchStore = FestivalRecentSearchStore(
        load: { userID in userID == "user-a" ? ["A 검색"] : [] },
        add: { _, _ in [] },
        remove: { _, _ in [] },
        clear: { _ in }
      )
    }

    await store.send(.view(.reloadBookmarks(userID: "user-a"))) {
      $0.bookedUserID = "user-a"
      $0.recentSearches = ["A 검색"]
    }
    await store.send(.view(.reloadBookmarks(userID: "user-b"))) {
      $0.bookedUserID = "user-b"
      $0.recentSearches = []
    }
  }
}
