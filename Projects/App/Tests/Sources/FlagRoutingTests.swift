import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import FestiCoreUtility
import Foundation
import Testing
import TCAFlow
@testable import FestiCore
@testable import Festival

@MainActor
@Suite("깃발 탭 이동")
struct FlagRoutingTests {
  @Test("디렉토리 카드를 누르면 선택 축제 문맥으로 상세를 열고 탭바를 숨긴다")
  func cardTapOpensDetailWithContext() async throws {
    let state = try Self.flagTabState()
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }
    // 상세 상태의 표시 시각(now)은 만들 때의 기기 시각이라 경로·문맥만 확인한다.
    store.exhaustivity = .off

    await store.send(.flagDirectory(.directory(.cardTapped("flg_1"))))
    await store.receive { $0.flagDirectoryAction == .directory(.delegate(.detailRequested(flagID: "flg_1"))) }
    await store.receive(\.flagCoordinator.delegate.detailRequested)
    await store.receive(\.flagCoordinator.navigation.showDetail)

    let detail = try #require(store.state.flagCoordinatorState.routes.last?.screen.detail)
    #expect(detail.flagID == "flg_1")
    #expect(detail.context == Self.expectedContext)
    #expect(store.state.flagCoordinatorState.routes.count == 2)
    #expect(store.state.flagCoordinatorState.routes[1].isPush)
    #expect(store.state.shouldHideTabBar)
    #expect(!store.state.shouldReserveTabBarSpace)
  }

  @Test("상세 뒤로 가기와 스와이프는 디렉토리로 돌아가 탭바를 다시 보인다")
  func backAndSwipeCloseDetail() async throws {
    var state = try Self.flagTabState()
    state.flagCoordinatorState.routes.push(.detail(Self.detailState()))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }

    await store.send(.flagCoordinator(.router(.routeAction(
      id: 1,
      action: .detail(.view(.backTapped))
    ))))
    await store.receive(\.flagCoordinator.router.routeAction) {
      $0.flagCoordinatorState.routes.removeLast()
    }
    #expect(!store.state.shouldHideTabBar)
    #expect(store.state.shouldReserveTabBarSpace)

    var reopened = store.state
    reopened.flagCoordinatorState.routes.push(.detail(Self.detailState()))
    let swipeStore = TestStore(initialState: reopened) {
      MainTabCoordinator()
    }
    await swipeStore.send(.flagCoordinator(.router(.updateRoutes([
      reopened.flagCoordinatorState.routes[0]
    ])))) {
      $0.flagCoordinatorState.routes.removeLast()
    }
    #expect(!swipeStore.state.shouldHideTabBar)
  }

  @Test("상세의 팔로우 로그인·신고 로그인·약관 요청을 앱 시트로 넘긴다")
  func detailRequestsReachAppSheets() async throws {
    var state = try Self.flagTabState()
    state.flagCoordinatorState.routes.push(.detail(Self.detailState()))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }

    await store.send(.flagCoordinator(.router(.routeAction(
      id: 1,
      action: .detail(.delegate(.loginRequested))
    ))))
    await store.receive(\.flagCoordinator.delegate.followLoginRequested)
    await store.receive {
      guard case .delegate(.myFollowLoginRequested) = $0 else { return false }
      return true
    }

    await store.send(.flagCoordinator(.router(.routeAction(
      id: 1,
      action: .detail(.delegate(.reportLoginRequested))
    ))))
    await store.receive(\.flagCoordinator.delegate.loginRequested)
    await store.receive {
      guard case .delegate(.myLoginRequested) = $0 else { return false }
      return true
    }

    await store.send(.flagCoordinator(.router(.routeAction(
      id: 1,
      action: .detail(.delegate(.termsAcceptanceRequested))
    ))))
    await store.receive(\.flagCoordinator.delegate.termsAcceptanceRequested)
    await store.receive {
      guard case .delegate(.myProfileRefreshRequested) = $0 else { return false }
      return true
    }
  }

  @Test("상세에서 바꾼 팔로우를 디렉토리 카드에도 반영한다")
  func detailFollowSyncsDirectoryCard() async throws {
    var state = try Self.flagTabState()
    state.flagState.snapshot = Self.snapshot(followerCount: 10)
    state.flagCoordinatorState.routes.push(.detail(Self.detailState()))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }
    store.exhaustivity = .off

    await store.send(.flagCoordinator(.router(.routeAction(
      id: 1,
      action: .detail(.delegate(.followChanged(
        flagID: "flg_1",
        isFollowing: true,
        followerCount: 11
      )))
    ))))
    await store.receive {
      $0.flagDirectoryAction == .directory(.followChangedElsewhere(
        FestivalFlagFollowResult(
          flagID: "flg_1",
          isFollowing: true,
          followerCount: 11
        ),
        baseCount: 10
      ))
    }
    let snapshot = try #require(store.state.flagState.snapshot)
    let row = try #require(store.state.flagState.directory.rows(
      in: snapshot,
      isFailed: false
    ).first)
    #expect(row.isFollowing)
    #expect(row.followersText == "팔로워 11")
  }

  @Test("계정이 바뀌면 열린 상세에 새 문맥을 보내 다시 불러온다")
  func sessionChangeUpdatesOpenDetail() async throws {
    var state = try Self.flagTabState()
    state.flagCoordinatorState.routes.push(.detail(Self.detailState()))
    // 같은 축제에서 다른 계정(B)으로 바뀐 보드
    var board = try #require(state.festivalState.routes.last?.screen.liveBoard)
    board.sessionUserID = "user-b"
    state.festivalState.routes[state.festivalState.routes.count - 1].screen = .liveBoard(board)
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    } withDependencies: {
      $0.date = .constant(Date(timeIntervalSince1970: 0))
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(detail: { _ throws(FestivalFlagDetailError) in
        throw .unavailable
      })
    }
    store.exhaustivity = .off

    await store.send(.selectTab(.flag))
    await store.receive(\.flagCoordinator.navigation.updateDetailContext)
    await store.receive(\.flagCoordinator.router.routeAction)
    let detail = try #require(store.state.flagCoordinatorState.routes.last?.screen.detail)
    #expect(detail.context.accountID == "user-b")
    #expect(detail.context.hasSession)
    #expect(detail.content == .loading)
    await store.skipReceivedActions()
  }

  @Test("상세를 연 채 계정이 바뀌면 세션 변경만으로 새 계정 문맥을 보내 다시 불러온다")
  func accountSwitchWhileDetailOpenReloadsDetail() async throws {
    var state = try Self.flagTabState()
    // 이전 계정이 팔로우를 바꾼 값이 남아 있는 상세에서 시작한다.
    var detailState = Self.detailState()
    detailState.followOverride = .init(
      isFollowing: true,
      followerCount: 11
    )
    state.flagCoordinatorState.routes.push(.detail(detailState))
    let reloadGeneration = detailState.loadGeneration + 1
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    } withDependencies: {
      $0.date = .constant(Date(timeIntervalSince1970: 0))
      // 축제 보드는 계정이 바뀌면 최근 검색을 새 계정 기준으로 다시 읽는다.
      $0.festivalLibraryUseCase = MockFestivalLibraryUseCase(recentSearches: { _ in return [] })
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(detail: { _ throws(FestivalFlagDetailError) in
        throw .unavailable
      })
    }
    store.exhaustivity = .off

    // 홈이 계정 입력 변경을 축제 보드에 알리는 경로와 같다.
    await store.send(.festival(.sessionChanged(
      hasSession: true,
      userID: "user-b"
    )))
    await store.receive { action in
      guard case let .flagCoordinator(.router(.routeAction(
        id: _,
        action: .detail(.view(.contextChanged(context)))
      ))) = action else { return false }
      return context.accountID == "user-b"
    }
    // 새 계정 문맥으로 상세를 한 번 더 불러온다.
    await store.receive { action in
      guard case let .flagCoordinator(.router(.routeAction(
        id: _,
        action: .detail(.async(.load(generation: generation)))
      ))) = action else { return false }
      return generation == reloadGeneration
    }
    let detail = try #require(store.state.flagCoordinatorState.routes.last?.screen.detail)
    #expect(detail.context.accountID == "user-b")
    #expect(detail.followOverride == nil)
    await store.skipReceivedActions()
  }

  @Test("깃발 링크는 깃발 탭을 고르고 상세를 연다")
  func flagDeeplinkOpensDetail() async throws {
    var state = try Self.flagTabState()
    state.selectedTab = .live
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }
    store.exhaustivity = .off

    await store.send(.openDeeplink(.flag(id: "flg_9")))
    await store.receive(\.selectTab) {
      $0.previousTab = .live
      $0.selectedTab = .flag
    }
    await store.receive(\.flagCoordinator.navigation.showDetail)
    let detail = try #require(store.state.flagCoordinatorState.routes.last?.screen.detail)
    #expect(detail.flagID == "flg_9")
    #expect(detail.context == Self.expectedContext)
    #expect(store.state.shouldHideTabBar)
  }
}

// MARK: - 고정 값

private extension FlagRoutingTests {
  static let expectedContext = FestivalFlagDetailContext(
    zoneNames: ["zone_a": "리벳 스테이지 앞 왼쪽"],
    performances: [
      "set_a": .init(
        artist: "윤마치",
        stageName: "리벳 스테이지",
        startsAt: ISO8601DateFormatter().date(from: "2026-11-07T08:00:00Z")!,
        endsAt: ISO8601DateFormatter().date(from: "2026-11-07T08:50:00Z")!
      ),
    ],
    mySetIDs: ["set_a"],
    hasSession: true,
    accountID: "user-a",
    pinnedFlagID: "flg_1"
  )

  /// 깃발 탭에서 고른 축제(팩·내 일정·로그인)와 디렉토리 스냅샷이 있는 상태
  static func flagTabState() throws -> MainTabCoordinator.State {
    let payload = #"""
    {"id":"festival-a","zones":[{"id":"zone_a","name":"리벳 스테이지 앞 왼쪽"}],
     "sets":[
       {"id":"set_a","artist":"윤마치","stageName":"리벳 스테이지","startsAt":"2026-11-07T08:00:00Z","endsAt":"2026-11-07T08:50:00Z"},
       {"id":"set_broken","artist":"시간 없음","stageName":"리벳 스테이지","startsAt":null,"endsAt":null}
     ]}
    """#
    var festival = FestivalFeature.State(selectedFestivalID: "festival-a")
    festival.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(payload.utf8)
    )
    festival.mySchedule = .init(
      festivalID: "festival-a",
      setIDs: ["set_a"]
    )
    festival.hasSession = true
    festival.sessionUserID = "user-a"
    var state = MainTabCoordinator.State(selectedTab: .flag)
    state.festivalState.routes.push(.liveBoard(festival))
    state.flagState = FestivalFlagFeature.State(festivalID: "festival-a")
    state.flagState.snapshot = snapshot(followerCount: 10)
    state.flagState.viewState = .loaded
    return state
  }

  static func snapshot(followerCount: Int) -> FestivalLiveBoardSnapshot {
    let flag = FestivalLiveBoardSnapshot.Flag(
      id: "flg_1",
      name: "호락호락",
      status: "active",
      zoneID: nil,
      activity: nil,
      thumbnailURL: nil,
      followerCount: followerCount
    )
    return FestivalLiveBoardSnapshot(
      festivalID: "festival-a",
      activeFlags: [flag],
      followedFlags: [],
      crew: nil,
      pinnedFlagID: "flg_1",
      directoryFlags: [flag]
    )
  }

  static func detailState() -> FestivalFlagDetailFeature.State {
    return FestivalFlagDetailFeature.State(
      flagID: "flg_1",
      context: expectedContext,
      now: Date(timeIntervalSince1970: 0)
    )
  }
}

// MARK: - 깃발 디렉토리 액션 확인

extension MainTabCoordinator.Action {
  /// 깃발 탭 루트 디렉토리로 간 액션. 다른 액션이면 nil.
  var flagDirectoryAction: FestivalFlagFeature.Action? {
    guard case let .flagCoordinator(.router(.routeAction(
      id: 0,
      action: .directory(action)
    ))) = self else { return nil }
    return action
  }
}

extension AppCoordinator.Action {
  /// 홈 깃발 탭 디렉토리로 간 액션. 다른 액션이면 nil.
  var homeFlagDirectoryAction: FestivalFlagFeature.Action? {
    guard case let .scope(.home(action)) = self else { return nil }
    return action.flagDirectoryAction
  }
}
