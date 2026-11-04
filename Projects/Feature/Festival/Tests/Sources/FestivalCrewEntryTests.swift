import ComposableArchitecture
import Testing
@testable import Festival

@MainActor
struct FestivalCrewEntryTests {
  @Test func loggedOutCrewActionOpensContextualLogin() async {
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "fst")) {
      FestivalFeature()
    }

    await store.send(.view(.createCrewTapped))
    await store.receive(.delegate(.crewLoginRequested))
  }

  @Test func loggedInCrewActionOpensSheetForSelectedFestival() async {
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.hasSession = true
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.view(.createCrewTapped)) {
      $0.crewCreate = FestivalCrewCreateFeature.State(festivalID: "fst")
    }
    await store.send(.view(.createCrewTapped))
  }
}
