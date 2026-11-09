import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import FestiCoreUtility
import Foundation
import Testing
@testable import FestiCore

@MainActor
struct DeeplinkRoutingTests {
  private enum LookupError: Error { case unavailable }

  @Test("팩이 없는 위젯은 현재 탭에서 축제 목록으로 돌아간다")
  func noPackOpensFestivalListTab() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "fst_a")))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }

    await store.send(.openDeeplink(.festivalList)) {
      $0.previousTab = .my
      $0.selectedTab = .live
    }
    await store.receive(\.festival.showFestivalList) {
      $0.festivalState.routes.removeAll { !$0.screen.is(\.festivalList) }
    }
    #expect(store.state.festivalState.routes.count == 1)
    await store.finish()
  }

  @Test("공연 알림 링크는 축제를 고르고 타임테이블에서 공연 상세를 연다")
  func setDeeplinkOpensTimetableDetail() async {
    let store = TestStore(initialState: MainTabCoordinator.State(selectedTab: .my)) {
      MainTabCoordinator()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
      $0.festivalPackUseCase = MockFestivalPackUseCase(cachedPacks: { [] })
    }
    store.exhaustivity = .off

    await store.send(.openDeeplink(.set(
      festivalID: "fst_a",
      setID: "set_1"
    )))
    await store.receive(\.festival.openWidgetFestival)
    await store.receive(\.selectTab) {
      $0.selectedTab = .timetable
    }
    await store.receive(\.timetable.view.setTapped)
  }

  @Test("저장된 팩의 축제 ID만 코디네이터가 라이브 보드로 연다")
  func opensOnlyCachedPackFestival() async {
    let store = TestStore(initialState: FestivalCoordinator.State()) {
      FestivalCoordinator()
    } withDependencies: {
      $0.festivalPackUseCase = MockFestivalPackUseCase(cachedPacks: {
        [CachedFestivalPack(
          festivalID: "fst_a",
          packVersion: 1,
          etag: "etag",
          pack: Data()
        )]
      })
    }
    store.exhaustivity = .off

    await store.send(.openWidgetFestival("missing"))
    await store.receive {
      guard case .widgetPackValidated(id: "missing", available: false) = $0 else { return false }
      return true
    }
    #expect(store.state.routes.count == 1)

    await store.send(.openWidgetFestival("fst_a"))
    await store.receive {
      guard case .widgetPackValidated(id: "fst_a", available: true) = $0 else { return false }
      return true
    }
    await store.receive {
      guard case .router(.routeAction(
        id: 0,
        action: .festivalList(.view(.selectFestival("fst_a")))
      )) = $0 else { return false }
      return true
    }
    #expect(store.state.routes.last?.screen.liveBoard?.selectedFestivalID == "fst_a")

    await store.send(.showFestivalList)
    #expect(store.state.routes.count == 1)
  }

  @Test("캐시 조회 오류는 팩 없음으로 취급하지 않고 현재 화면에 안내한다")
  func cacheFailureKeepsCurrentRoute() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "fst_a")))
    let clock = TestClock()
    let store = TestStore(initialState: state) {
      FestivalCoordinator()
    } withDependencies: {
      $0.festivalPackUseCase = MockFestivalPackUseCase(cachedPacks: {
        throw LookupError.unavailable
      })
      $0.continuousClock = clock
    }
    store.exhaustivity = .off

    await store.send(.openWidgetFestival("fst_a"))
    await store.receive {
      guard case .widgetPackLookupFailed = $0 else { return false }
      return true
    }
    #expect(store.state.routes.count == 2)
    #expect(store.state.routes.last?.screen.liveBoard?.toast == .packDownloadFailed)

    await clock.advance(by: .seconds(2))
    await store.receive {
      guard case .widgetPackLookupToastExpired = $0 else { return false }
      return true
    }
    #expect(store.state.routes.last?.screen.liveBoard?.toast == nil)
    await store.finish()
  }
}
