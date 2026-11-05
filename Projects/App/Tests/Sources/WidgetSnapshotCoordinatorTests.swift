import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import FestiCorePackInterface
import Foundation
import Testing
import TCAFlow
@testable import FestiCore
@testable import Festival

@MainActor
struct WidgetSnapshotCoordinatorTests {
  @Test("위젯은 숨은 목록이 아닌 최상단 라이브 보드의 축제를 사용한다")
  func activeRouteOwnsSnapshot() async throws {
    let saves = LockIsolated<[FestivalWidgetSnapshot?]>([])
    let home = try homeWithTwoFestivals()
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date = .constant(Date(timeIntervalSince1970: 0))
      $0.festivalWidgetClient = FestivalWidgetClient(save: { snapshot in
        saves.withValue { $0.append(snapshot) }
      })
    }
    store.exhaustivity = .off

    #expect(store.state.activeWidgetSnapshotContent?.festivalID == "board")
    await store.send(.scope(.home(.scopeAction(.festival(.showFestivalList)))))
    await store.finish()

    #expect(store.state.activeWidgetSnapshotContent?.festivalID == "list")
    #expect(saves.value.map { $0?.festivalID } == ["list"])
  }

  @Test("계정 만료 후에도 받은 팩은 표시하고 개인 일정은 공유하지 않는다")
  func sessionExpiryClearsPersonalWidgetData() async throws {
    let saves = LockIsolated<[FestivalWidgetSnapshot?]>([])
    let home = try homeWithTwoFestivals()
    let store = TestStore(initialState: AppCoordinator.State.home(home)) {
      AppCoordinator()
    } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date = .constant(Date(timeIntervalSince1970: 0))
      $0.festivalWidgetClient = FestivalWidgetClient(save: { snapshot in
        saves.withValue { $0.append(snapshot) }
      })
    }
    store.exhaustivity = .off

    #expect(store.state.activeWidgetSnapshotContent?.performances.first?.isSaved == true)

    await store.send(.inner(.sessionExpired))
    await store.finish()

    let snapshot = try #require(store.state.activeWidgetSnapshotContent)
    #expect(snapshot.festivalID == "board")
    #expect(snapshot.hasPack)
    #expect(snapshot.performances.first?.isSaved == false)
    #expect(snapshot.crewName == nil)
    #expect(saves.value.count == 1)
    let saved = try #require(saves.value.first ?? nil)
    #expect(saved.performances.first?.isSaved == false)
  }

  @Test("상위 세션이 없으면 자식에 이전 일정이 남아 있어도 공개 팩만 공유한다")
  func anonymousWidgetKeepsPackWithoutSavedSchedule() throws {
    var home = try homeWithTwoFestivals()
    home.authFlow.hasSession = false

    let snapshot = try #require(AppCoordinator.State.home(home).activeWidgetSnapshotContent)

    #expect(snapshot.hasPack)
    #expect(snapshot.festivalName == "보드")
    #expect(snapshot.performances.first?.artist == "가수")
    #expect(snapshot.performances.first?.isSaved == false)
    #expect(snapshot.crewName == nil)
    #expect(snapshot.leaveAt == nil)
  }

  private func homeWithTwoFestivals() throws -> MainTabCoordinator.State {
    var home = MainTabCoordinator.State(selectedTab: .my)
    home.authFlow.hasSession = true
    var list = FestivalFeature.State(selectedFestivalID: "list")
    list.catalog = [FestivalCatalogItem(
      id: "list",
      name: "목록",
      packVersion: 0
    )]
    var board = FestivalFeature.State(selectedFestivalID: "board")
    board.catalog = [FestivalCatalogItem(
      id: "board",
      name: "보드",
      packVersion: 0
    )]
    let documentData = Data(#"{"id":"board","sets":[{"id":"set_1","artist":"가수","stageName":"메인","startsAt":"2026-11-05T10:00:00+09:00","endsAt":"2026-11-05T11:00:00+09:00"}]}"#.utf8)
    board.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: documentData
    )
    board.cachedPacks["board"] = CachedFestivalPack(
      festivalID: "board",
      packVersion: 1,
      etag: "e",
      pack: documentData
    )
    board.hasSession = true
    board.mySchedule = .init(
      festivalID: "board",
      setIDs: ["set_1"]
    )
    home.tabs.festival.routes[0].screen = .festivalList(list)
    home.tabs.festival.routes.push(.liveBoard(board))
    return home
  }
}
