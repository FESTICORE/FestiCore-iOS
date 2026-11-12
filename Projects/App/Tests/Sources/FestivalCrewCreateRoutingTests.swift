//
//  FestivalCrewCreateRoutingTests.swift
//  FestiCoreTests
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import Foundation
import Testing
import TCAFlow
@testable import FestiCore

/// 크루 만들기는 시트가 아니라 라이브 탭 경로에 push하는 화면이다.
@MainActor
struct FestivalCrewCreateRoutingTests {
  private let crew = FestivalCrew(
    id: "crew",
    festivalID: "festival",
    name: "펜타",
    ownerID: "user-me",
    members: [],
    inviteCode: "K7P2QX",
    inviteExpiresAt: Date(timeIntervalSince1970: 1_786_287_600)
  )

  private func liveBoardTabState() -> MainTabCoordinator.State {
    var state = MainTabCoordinator.State()
    var board = FestivalFeature.State(selectedFestivalID: "festival")
    board.hasSession = true
    state.festivalState.routes.push(.liveBoard(board))
    return state
  }

  private func send(
    _ action: FestivalCoordinator.FestivalScreen.Action,
    id: Int,
    to state: inout MainTabCoordinator.State
  ) {
    _ = FestivalCoordinator().handleRoute(
      state: &state.festivalState,
      action: .router(.routeAction(
        id: id,
        action: action
      ))
    )
  }

  @Test("크루 만들기는 만들기 화면을 push하고 탭바를 숨기며, 뒤로 가면 라이브 보드로 돌아온다")
  func pushesCreateScreenAndGoesBack() {
    var state = liveBoardTabState()
    #expect(!state.shouldHideTabBar)

    send(
      .liveBoard(.delegate(.crewCreateRequested(festivalID: "festival"))),
      id: 1,
      to: &state
    )
    #expect(state.festivalState.routes.count == 3)
    #expect(state.festivalState.routes.last?.screen.crewCreate?.festivalID == "festival")
    #expect(state.isCrewOnTop)
    #expect(state.shouldHideTabBar)

    // 이미 열려 있으면 다시 쌓지 않는다.
    send(
      .liveBoard(.delegate(.crewCreateRequested(festivalID: "festival"))),
      id: 1,
      to: &state
    )
    #expect(state.festivalState.routes.count == 3)

    send(
      .crewCreate(.delegate(.closeRequested)),
      id: 2,
      to: &state
    )
    #expect(state.festivalState.routes.count == 2)
    #expect(state.festivalState.routes.last?.screen.is(\.liveBoard) == true)
    #expect(!state.shouldHideTabBar)
  }

  @Test("만든 뒤 크루 보기는 만들기 화면을 크루 화면으로 바꾸고, 크루 화면에서 뒤로 가면 라이브 보드다")
  func openCrewReplacesCreateScreen() {
    var state = liveBoardTabState()
    send(
      .liveBoard(.delegate(.crewCreateRequested(festivalID: "festival"))),
      id: 1,
      to: &state
    )

    send(
      .crewCreate(.delegate(.openCrewRequested(crewID: "crew"))),
      id: 2,
      to: &state
    )
    #expect(state.festivalState.routes.count == 3)
    #expect(!state.festivalState.routes.contains { $0.screen.is(\.crewCreate) })
    #expect(state.festivalState.routes.last?.screen.crew?.crewID == "crew")
    #expect(state.shouldHideTabBar)

    send(
      .crew(.delegate(.backRequested)),
      id: 2,
      to: &state
    )
    #expect(state.festivalState.routes.last?.screen.is(\.liveBoard) == true)
    #expect(!state.shouldHideTabBar)
  }

  @Test("만들면 화면은 초대 단계로 남고 라이브 보드의 크루 카드를 다시 받는다")
  func createdReloadsLiveBoard() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    state.routes.push(.crewCreate(.init(festivalID: "festival")))
    let store = TestStore(initialState: state) { FestivalCoordinator() }

    await store.send(.router(.routeAction(
      id: 2,
      action: .crewCreate(.delegate(.created(crew)))
    )))
    await store.receive { action in
      guard case .router(.routeAction(
        id: 1,
        action: .liveBoard(.view(.retryLiveBoard))
      )) = action else { return false }
      return true
    }
    #expect(store.state.routes.last?.screen.is(\.crewCreate) == true)
  }

  @Test("만들기 화면에서 세션이 끊기면 화면을 닫고 크루 로그인을 요청한다")
  func loginRequestClosesCreateScreen() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    state.routes.push(.crewCreate(.init(festivalID: "festival")))
    let store = TestStore(initialState: state) { FestivalCoordinator() }

    await store.send(.router(.routeAction(
      id: 2,
      action: .crewCreate(.delegate(.loginRequested))
    ))) {
      $0.routes.removeAll { $0.screen.is(\.crewCreate) }
    }
    await store.receive { action in
      guard case .delegate(.crewLoginRequested) = action else { return false }
      return true
    }
  }

  @Test("초대 링크 참여 화면의 로그인 요청은 크루 참여 문맥으로 올린다")
  func crewJoinLoginRequestUsesJoinContext() async {
    var state = FestivalCoordinator.State()
    state.routes.push(.crewJoin(.init(
      code: "K7P2QX",
      hasSession: false
    )))
    let store = TestStore(initialState: state) { FestivalCoordinator() }

    await store.send(.router(.routeAction(
      id: 1,
      action: .crewJoin(.delegate(.loginRequested))
    )))
    await store.receive { action in
      guard case .delegate(.crewJoinLoginRequested(crewName: nil)) = action else { return false }
      return true
    }
  }

  @Test("계정이 바뀌면 열린 만들기 화면을 닫는다")
  func accountChangeClosesCreateScreen() {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))
    state.routes.push(.crewCreate(.init(festivalID: "festival")))

    state.clearAccountData()

    #expect(state.routes.count == 2)
    #expect(!state.routes.contains { $0.screen.is(\.crewCreate) })
  }
}
