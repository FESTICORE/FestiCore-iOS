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

  /// 크루 만들기는 시트가 아니라 화면 이동이라 부모(코디네이터)에게 맡긴다.
  @Test func loggedInCrewActionRequestsCreateScreenForSelectedFestival() async {
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.hasSession = true
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.view(.createCrewTapped))
    await store.receive(.delegate(.crewCreateRequested(festivalID: "fst")))
  }
}
