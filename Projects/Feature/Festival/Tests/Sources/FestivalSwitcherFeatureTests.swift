import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalSwitcherFeatureTests {
  @Test("예매한 페스티벌을 선택하면 부모에게 ID를 전달한다")
  func selectedFestivalIsDelegated() async {
    let store = TestStore(initialState: FestivalSwitcherFeature.State(
      festivals: [item(id: "one"), item(id: "two")],
      selectedFestivalID: "one"
    )) { FestivalSwitcherFeature() }

    await store.send(.view(.festivalTapped("two")))
    await store.receive(.delegate(.festivalSelected("two")))
  }

  @Test("목록에 없는 ID는 부모에게 전달하지 않는다")
  func unknownFestivalIsIgnored() async {
    let store = TestStore(initialState: FestivalSwitcherFeature.State(
      festivals: [item(id: "one")],
      selectedFestivalID: "one"
    )) { FestivalSwitcherFeature() }

    await store.send(.view(.festivalTapped("unknown")))
  }

  @Test("전체 페스티벌 보기는 목록 경로를 요청한다")
  func seeAllFestivalsIsDelegated() async {
    let store = TestStore(initialState: FestivalSwitcherFeature.State(
      festivals: [],
      selectedFestivalID: nil
    )) { FestivalSwitcherFeature() }

    await store.send(.view(.allFestivalsTapped))
    await store.receive(.delegate(.seeAllFestivals))
  }

  @Test("페스티벌 바꾸기 목록은 북마크가 아니라 받은 팩 기준이다")
  func switcherListsDownloadedPacksOnly() async {
    var initial = FestivalFeature.State(selectedFestivalID: "downloaded")
    initial.catalog = [
      FestivalCatalogItem(
        id: "downloaded",
        name: "받은 축제",
        firstDate: "2099-11-21",
        packVersion: 1
      ),
      FestivalCatalogItem(
        id: "booked",
        name: "북마크만 한 축제",
        firstDate: "2099-11-22",
        packVersion: 1
      )
    ]
    initial.cachedPacks = [
      "downloaded": cachedPack(
        id: "downloaded",
        name: "받은 축제"
      ),
      "offline": cachedPack(
        id: "offline",
        name: "목록 밖 받은 축제"
      )
    ]
    initial.bookedFestivalIDs = ["booked"]
    let store = TestStore(initialState: initial) {
      FestivalFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_792_475_400)
    }
    store.exhaustivity = .off

    await store.send(.view(.festivalSwitchTapped))

    #expect(Set(store.state.festivalSwitcher?.festivals.map(\.id) ?? []) == ["downloaded", "offline"])
    #expect(store.state.festivalSwitcher?.selectedFestivalID == "downloaded")
  }

  private func cachedPack(
    id: String,
    name: String
  ) -> CachedFestivalPack {
    return CachedFestivalPack(
      festivalID: id,
      packVersion: 1,
      etag: "v1",
      pack: Data(#"{"id":"\#(id)","name":"\#(name)","packVersion":1}"#.utf8)
    )
  }

  private func item(id: String) -> FestivalSwitcherFeature.State.Item {
    return .init(
      id: id,
      name: id,
      subtitle: "오늘 · DAY 1 진행 중",
      thumbnailURL: nil
    )
  }
}
