import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCore

@MainActor
struct WidgetDeepLinkRoutingTests {
  private enum LookupError: Error { case unavailable }

  @Test("위젯 URL은 목록과 축제 상세만 허용하며 OAuth URL은 분기하지 않는다")
  func parsesOnlyWidgetRoutes() {
    #expect(WidgetDeepLink(url: URL(string: "festicore://festival")!) == .festivalList)
    #expect(WidgetDeepLink(url: URL(string: "festicore://festival/fst_a")!) == .festival("fst_a"))
    #expect(WidgetDeepLink(url: URL(string: "festicore://festival/")!) == nil)
    #expect(WidgetDeepLink(url: URL(string: "festicore://festival/a%2Fb")!) == nil)
    #expect(WidgetDeepLink(url: URL(string: "festicore://festival/fst?other=1")!) == nil)
    #expect(WidgetDeepLink(url: URL(string: "com.googleusercontent.apps.sample:/oauth")!) == nil)
  }

  @Test("팩이 없는 위젯은 현재 탭에서 축제 목록으로 돌아간다")
  func noPackOpensFestivalListTab() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.tabs.festival.routes.push(.liveBoard(.init(selectedFestivalID: "fst_a")))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }

    await store.send(.openWidgetRoute(.festivalList)) {
      $0.previousTab = .my
      $0.selectedTab = .live
    }
    await store.receive(\.scopeAction.festival.showFestivalList) {
      $0.tabs.festival.routes.removeAll { !$0.screen.is(\.festivalList) }
    }
    #expect(store.state.tabs.festival.routes.count == 1)
    await store.finish()
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
