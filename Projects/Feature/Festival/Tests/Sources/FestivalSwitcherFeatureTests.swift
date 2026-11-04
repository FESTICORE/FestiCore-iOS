import ComposableArchitecture
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalSwitcherFeatureTests {
  @Test("예매한 페스티벌을 선택하면 부모에게 ID를 전달한다")
  func selectedFestivalIsDelegated() async {
    let store = TestStore(initialState: FestivalSwitcherFeature.State(
      festivals: [item(id: "one"), item(id: "two")], selectedFestivalID: "one"
    )) { FestivalSwitcherFeature() }

    await store.send(.view(.festivalTapped("two")))
    await store.receive(.delegate(.festivalSelected("two")))
  }

  @Test("목록에 없는 ID는 부모에게 전달하지 않는다")
  func unknownFestivalIsIgnored() async {
    let store = TestStore(initialState: FestivalSwitcherFeature.State(
      festivals: [item(id: "one")], selectedFestivalID: "one"
    )) { FestivalSwitcherFeature() }

    await store.send(.view(.festivalTapped("unknown")))
  }

  @Test("전체 페스티벌 보기는 목록 경로를 요청한다")
  func seeAllFestivalsIsDelegated() async {
    let store = TestStore(initialState: FestivalSwitcherFeature.State(
      festivals: [], selectedFestivalID: nil
    )) { FestivalSwitcherFeature() }

    await store.send(.view(.allFestivalsTapped))
    await store.receive(.delegate(.seeAllFestivals))
  }

  private func item(id: String) -> FestivalSwitcherFeature.State.Item {
    return .init(id: id, name: id, subtitle: "오늘 · DAY 1 진행 중", thumbnailURL: nil)
  }
}
