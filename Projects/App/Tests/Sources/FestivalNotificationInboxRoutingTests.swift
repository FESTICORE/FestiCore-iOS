import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import Testing
import TCAFlow
@testable import FestiCore

@MainActor
struct FestivalNotificationInboxRoutingTests {
  @Test("북마크 결과 토스트는 현재 보이는 축제 화면에만 보인다")
  func bookmarkToastTargetsTopFestivalRoute() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "fst")))
    let clock = TestClock()
    let store = TestStore(initialState: state) { FestivalCoordinator() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.continuousClock = clock
    }
    store.exhaustivity = .off

    await store.send(.bookmarkSaved(id: "fst", booked: true))
    await store.receive {
      guard case .router(.routeAction(
        id: 1, action: .liveBoard(.view(.bookmarkSaved(id: "fst", booked: true)))
      )) = $0 else { return false }
      return true
    }
    #expect(store.state.routes[0].screen.festivalList?.toast == nil)
    #expect(store.state.routes[1].screen.liveBoard?.toast == .bookmarked)
  }

  @Test("로그인한 라이브 보드에서 알림함을 열고 뒤로 돌아온다")
  func opensInboxAndReturns() async {
    var state = FestivalCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "fst")
    board.hasSession = true
    state.routes.push(.liveBoard(board))
    let store = TestStore(initialState: state) { FestivalCoordinator() }
    store.exhaustivity = .off

    await store.send(.router(.routeAction(id: 1, action: .liveBoard(.delegate(.notificationInboxRequested)))))
    #expect(store.state.routes.last?.screen.is(\.notificationInbox) == true)
    await store.send(.router(.routeAction(id: 2, action: .notificationInbox(.delegate(.backRequested)))))
    #expect(store.state.routes.count == 2)
  }

  @Test("알림함이 열린 상태에서 계정이 바뀌면 알림함과 배지를 비운다")
  func accountChangeClearsInboxAndBadge() {
    var state = FestivalCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "fst")
    board.hasSession = true
    board.notificationUnreadCount = 4
    state.routes.push(.liveBoard(board))
    state.routes.push(.notificationInbox(.init()))

    state.clearAccountData()

    #expect(state.routes.count == 2)
    #expect(!state.routes.contains { $0.screen.is(\.notificationInbox) })
    #expect(state.routes.last?.screen.liveBoard?.notificationUnreadCount == 0)
  }

  @Test("세션의 사용자가 바뀌면 이전 사용자의 알림함을 즉시 닫는다")
  func switchedAccountClosesInbox() {
    var state = FestivalCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "fst")
    board.hasSession = true
    board.sessionUserID = "user-a"
    state.routes.push(.liveBoard(board))
    state.routes.push(.notificationInbox(.init()))

    _ = FestivalCoordinator().handleRoute(
      state: &state, action: .sessionChanged(hasSession: true, userID: "user-b")
    )

    #expect(state.routes.count == 2)
    #expect(!state.routes.contains { $0.screen.is(\.notificationInbox) })
  }

  @Test("사용자 ID가 미확정인 세션에서 계정이 바뀌어도 알림함을 닫는다")
  func unknownPreviousAccountClosesInbox() {
    var state = FestivalCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "fst")
    board.hasSession = true
    board.sessionUserID = nil
    state.routes.push(.liveBoard(board))
    state.routes.push(.notificationInbox(.init()))

    _ = FestivalCoordinator().handleRoute(
      state: &state, action: .sessionChanged(hasSession: true, userID: "user-b")
    )

    #expect(state.routes.count == 2)
    #expect(!state.routes.contains { $0.screen.is(\.notificationInbox) })
  }

  @Test("알림의 축제가 카탈로그에 있으면 알림함을 닫고 보드로 돌아간다")
  func catalogFestivalClosesInbox() {
    var state = FestivalCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "fst")
    board.catalog = [FestivalCatalogItem(id: "fst", name: "축제", packVersion: 0)]
    state.routes.push(.liveBoard(board))
    state.routes.push(.notificationInbox(.init()))

    _ = FestivalCoordinator().handleRoute(state: &state, action: .router(.routeAction(
      id: 2, action: .notificationInbox(.delegate(.rowOpened(festivalID: "fst", markReadID: nil)))
    )))

    #expect(state.routes.count == 2)
    #expect(state.routes.last?.screen.liveBoard?.selectedFestivalID == "fst")
  }

  @Test("카탈로그에 없는 축제의 알림은 알림함에 남는다")
  func unknownFestivalKeepsInbox() {
    var state = FestivalCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "fst")
    board.catalog = [FestivalCatalogItem(id: "fst", name: "축제", packVersion: 0)]
    state.routes.push(.liveBoard(board))
    state.routes.push(.notificationInbox(.init()))

    _ = FestivalCoordinator().handleRoute(state: &state, action: .router(.routeAction(
      id: 2, action: .notificationInbox(.delegate(.rowOpened(festivalID: "missing", markReadID: nil)))
    )))

    #expect(state.routes.count == 3)
    #expect(state.routes.last?.screen.is(\.notificationInbox) == true)
  }

  @Test("알림함에서는 라이브 탭바와 탭바 여백을 숨긴다")
  func inboxHidesTabBar() {
    var state = MainTabCoordinator.State()
    state.festivalState.routes.push(.liveBoard(.init()))
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    state.festivalState.routes.push(.notificationInbox(.init()))
    #expect(state.isNotificationInboxOnTop)
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)
  }
}
