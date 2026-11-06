import ComposableArchitecture
import FeatureAssembly
import TCAFlow
import Testing
import FestivalDomainInterface
import Foundation

@testable import FestiCore

@MainActor
struct TimetableRoutingTests {
  @Test func selectedFestivalWithoutPackShowsFailureInsteadOfUnpublished() async {
    var home = MainTabCoordinator.State()
    var festival = FestivalFeature.State(selectedFestivalID: "festival")
    festival.onlineDetailFailed = true
    festival.connection = .offline
    home.festivalState.routes.push(.liveBoard(festival))
    home.timetableState.festivalID = "festival"
    home.timetableState.scheduleSync = .loading
    let store = Store(initialState: home) { MainTabCoordinator() }
    await store.send(.selectTab(.timetable)).finish()
    #expect(store.withState { $0.timetableState.contentStatus } == .failed)
    #expect(store.withState { $0.timetableState.lineup.isEmpty })
  }

  @Test func selectedFestivalInputLoadsRealLineupAndOfflineStatus() async throws {
    let data = Data(#"{"id":"festival","artists":[{"name":"아티스트"}]}"#.utf8)
    let document = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: data
    )
    var home = MainTabCoordinator.State()
    var festival = FestivalFeature.State(selectedFestivalID: "festival")
    festival.selectedPack = document
    festival.connection = .offline
    home.festivalState.routes.push(.liveBoard(festival))
    home.timetableState.festivalID = "festival"
    home.timetableState.scheduleSync = .loading
    let store = Store(initialState: home) { MainTabCoordinator() }
    await store.send(.selectTab(.timetable)).finish()
    #expect(store.withState { $0.timetableState.contentStatus } == .unpublished)
    #expect(store.withState { $0.timetableState.lineup.first?.artists } == ["아티스트"])
    #expect(store.withState { $0.timetableState.offlineMessage } == "오프라인 · 저장된 정보")
  }

  @Test func searchPushHidesTabBarAndBackRestoresIt() async {
    var state = MainTabCoordinator.State(selectedTab: .timetable)
    state.timetableCoordinatorState.setList = .init(
      mode: .search,
      days: []
    )
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)
    #expect(state.timetableCoordinatorState.routes.last?.screen.is(\.setList) == true)
    let store = TestStore(initialState: state.timetableCoordinatorState) { TimetableCoordinator() }
    await store.send(.setList(.view(.backTapped)))
    await store.receive(\.setList.delegate.close) { $0.setList = nil }
  }

  @Test func mapperOnlyMarksChangesWhenPreviousPerformanceExists() throws {
    let first = try pack(start: "2026-08-07T17:00:00+09:00")
    let baseline = FestivalPackTimetableMapper.days(from: first)
    #expect(baseline.first?.sets.first?.previousStart == nil)
    let second = try pack(start: "2026-08-07T17:20:00+09:00")
    let changed = FestivalPackTimetableMapper.days(
      from: second,
      previousDays: baseline
    )
    #expect(changed.first?.sets.first?.previousStart == 1020)
    #expect(changed.first?.sets.first?.start == 1040)
    let repeated = FestivalPackTimetableMapper.days(
      from: second,
      previousDays: changed
    )
    #expect(repeated == changed)
  }

  @Test func unpublishedLineupDoesNotInventArtistDates() throws {
    let data = Data(#"{"id":"festival","days":[{"date":"2026-08-07"}],"artists":[{"name":"아티스트"}]}"#.utf8)
    let pack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: data
    )
    #expect(FestivalPackTimetableMapper.lineup(from: pack).first?.title == "공개된 라인업")
    #expect(FestivalPackTimetableMapper.days(from: pack).first?.sets.isEmpty == true)
  }

  private func pack(start: String) throws -> FestivalPackDocument {
    let data = Data("""
    {"id":"festival","timetable":[{"id":"set","artist":"아티스트","startsAt":"\(start)","endsAt":"2026-08-07T18:00:00+09:00"}]}
    """.utf8)
    return try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: data
    )
  }

  @Test("타임테이블 버튼의 Router 액션이 일정 선택을 push하고 나중에 액션으로 pop한다")
  func routedSchedulePickButtonPushesAndLaterPops() async {
    var state = TimetableCoordinator.State()
    state.timetableState.festivalID = "festival"
    state.timetableState.scheduleSync = .ready
    let store = TestStore(initialState: state) { TimetableCoordinator() }

    await store.send(.router(.routeAction(
      id: 0,
      action: .timetable(.view(.schedulePickTapped))
    )))
    await store.receive(\.timetable.view.schedulePickTapped) {
      $0.timetableState.destination = .schedulePick(.init(
        festivalID: "festival",
        days: []
      ))
    }
    #expect(store.state.routes.count == 2)
    #expect(store.state.routes[1].isPush)
    #expect(store.state.routes[1].screen.is(\.schedulePick))
    var home = MainTabCoordinator.State(selectedTab: .timetable)
    home.timetableCoordinatorState = store.state
    #expect(home.shouldHideTabBar)
    #expect(!home.shouldReserveTabBarSpace)

    await store.send(.router(.routeAction(
      id: 1,
      action: .schedulePick(.view(.laterTapped))
    )))
    await store.receive(\.timetable.destination.presented.schedulePick.view.laterTapped)
    await store.receive(\.timetable.destination.presented.schedulePick.delegate.later) {
      $0.timetableState.destination = nil
    }
    #expect(store.state.routes.count == 1)
    home.timetableCoordinatorState = store.state
    #expect(!home.shouldHideTabBar)
    #expect(home.shouldReserveTabBarSpace)
  }

  @Test("내 일정 고르기에서는 탭바와 여백을 숨기고 뒤로 가면 복원한다")
  func schedulePickHidesTabBarUntilDismissed() {
    var state = MainTabCoordinator.State(selectedTab: .timetable)
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    state.timetableState.destination = .schedulePick(.init(
      festivalID: "festival",
      days: [],
      selectedSetIDs: [],
      previousClientAt: nil
    ))
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)

    state.selectedTab = .my
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    state.selectedTab = .timetable
    state.timetableState.destination = nil
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)
  }

  @Test("내 일정 고르기는 팩 상태와 별개인 push 경로로 표시한다")
  func schedulePickIsPushRoute() {
    var state = TimetableCoordinator.State()
    #expect(state.routes.count == 1)

    state.timetableState.destination = .schedulePick(
      .init(
        festivalID: "festival",
        days: [],
        selectedSetIDs: [],
        previousClientAt: nil
      ))

    #expect(state.routes.count == 2)
    #expect(state.routes[1].isPush)
    #expect(state.routes[1].screen.is(\.schedulePick))
  }

  @Test("뒤로 가기는 기존 일정 선택 목적지를 닫는다")
  func popDismissesSchedulePick() async {
    var state = TimetableCoordinator.State()
    state.timetableState.destination = .schedulePick(
      .init(
        festivalID: "festival",
        days: [],
        selectedSetIDs: [],
        previousClientAt: nil
      ))
    let root = state.routes[0]
    let store = TestStore(initialState: state) { TimetableCoordinator() }
    store.exhaustivity = .off

    await store.send(.router(.updateRoutes([root])))
    await store.receive {
      guard case .timetable(.destination(.dismiss)) = $0 else { return false }
      return true
    }
    #expect(store.state.timetableState.destination == nil)
  }

  @Test("닫힌 일정 선택 화면의 액션은 무시한다")
  func ignoresStaleSchedulePickAction() async {
    let store = TestStore(initialState: TimetableCoordinator.State()) { TimetableCoordinator() }
    await store.send(.router(.routeAction(
      id: 1,
      action: .schedulePick(.view(.laterTapped))
    )))
  }

  @Test("일정 저장 결과를 상위 탭에 전달한다")
  func forwardsScheduleSaved() async {
    let store = TestStore(initialState: TimetableCoordinator.State()) { TimetableCoordinator() }
    await store.send(
      .timetable(.delegate(.scheduleSaved(
        festivalID: "festival",
        setIDs: ["set-a"]
      ))))
    await store.receive(\.delegate.scheduleSaved)
  }
}
