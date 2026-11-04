import ComposableArchitecture
import FestivalDomainInterface
import Testing
@testable import Festival

struct FestivalCatalogPaginationTests {
  @Test @MainActor func bookedFilterBeforeFirstPageFetchesTheCompleteCatalog() async {
    let first = FestivalCatalogItem(id: "fst_first", name: "첫 축제", packVersion: 0)
    let booked = FestivalCatalogItem(id: "fst_booked", name: "예매 축제", packVersion: 0)
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.festivalCatalogUseCase = MockFestivalCatalogUseCase(refreshFestivals: { [first, booked] })
    }

    await store.send(.view(.listFilterChanged(.booked))) {
      $0.listInteraction.selectedFilter = .booked
    }
    await store.send(.inner(.catalogPageLoaded(.init(items: [first], nextCursor: "cursor-a"), after: nil))) {
      $0.viewState = .loaded
      $0.catalog = [first]
      $0.catalogNextCursor = "cursor-a"
      $0.selectedFestivalID = first.id
      $0.connection = .unavailable
    }
    await store.receive(\.inner.catalogRefreshed) {
      $0.catalog = [first, booked]
      $0.catalogNextCursor = nil
    }
    await store.finish()
  }

  @Test @MainActor func keepsSavedSelectionUntilLaterPageArrives() async {
    let first = FestivalCatalogItem(id: "fst_first", name: "첫 축제", packVersion: 0)
    let saved = FestivalCatalogItem(id: "fst_saved", name: "저장 축제", packVersion: 0)
    var state = FestivalFeature.State()
    state.selectedFestivalID = saved.id
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.inner(.catalogPageLoaded(.init(items: [first], nextCursor: "cursor-a"), after: nil))) {
      $0.viewState = .loaded
      $0.catalog = [first]
      $0.catalogNextCursor = "cursor-a"
    }
    #expect(store.state.selectedFestivalID == saved.id)
    await store.send(.inner(.catalogPageLoaded(.init(items: [saved], nextCursor: nil), after: "cursor-a"))) {
      $0.catalog = [first, saved]
      $0.catalogNextCursor = nil
      $0.connection = .unavailable
    }
    await store.finish()
    #expect(store.state.selectedFestival?.id == saved.id)
  }

  @Test @MainActor func appendsPagesAndKeepsFirstCopyOfDuplicateFestival() async {
    let first = FestivalCatalogItem(id: "fst_first", name: "첫 축제", packVersion: 0)
    let duplicate = FestivalCatalogItem(id: "fst_first", name: "중복 축제", packVersion: 0)
    let second = FestivalCatalogItem(id: "fst_second", name: "둘째 축제", packVersion: 0)
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.inner(.catalogPageLoaded(.init(items: [first], nextCursor: "cursor-a"), after: nil))) {
      $0.viewState = .loaded
      $0.catalog = [first]
      $0.catalogNextCursor = "cursor-a"
      $0.selectedFestivalID = first.id
      $0.connection = .unavailable
    }
    await store.send(.inner(.catalogPageLoaded(.init(items: [duplicate, second], nextCursor: nil), after: "cursor-a"))) {
      $0.catalog = [first, second]
      $0.catalogNextCursor = nil
    }
    await store.finish()
    #expect(store.state.festivals.map(\.name) == ["첫 축제", "둘째 축제"])
  }
}
