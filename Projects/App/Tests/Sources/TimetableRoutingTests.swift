import ComposableArchitecture
import FeatureAssembly
import TCAFlow
import Testing

@testable import FestiCore

@MainActor
struct TimetableRoutingTests {
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
