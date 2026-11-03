//
//  FestivalBearerRoutingTests.swift
//  FestiCoreTests
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FeatureAssembly
import Testing
import TCAFlow
@testable import FestiCore

@MainActor
struct FestivalBearerRoutingTests {
  private func liveBoardState() -> FestivalCoordinator.State {
    var state = FestivalCoordinator.State()
    state.routes.push(.liveBoard(.init(selectedFestivalID: "fst")))
    return state
  }

  @Test("라이브 보드의 기수 버튼은 기수 보드를 전체 화면으로 띄우고 닫으면 내린다")
  func presentsAndDismissesBearerBoard() async {
    let store = TestStore(initialState: liveBoardState()) { FestivalCoordinator() }

    await store.send(.router(.routeAction(
      id: 1,
      action: .liveBoard(.delegate(.bearerBoardRequested(festivalID: "fst", flagID: "flg_1", userID: "usr_me")))
    ))) {
      $0.routes.presentCover(.bearerBoard(.init(festivalID: "fst", flagID: "flg_1", viewerUserID: "usr_me")))
    }
    await store.send(.router(.routeAction(id: 2, action: .bearerBoard(.delegate(.closeRequested))))) {
      $0.routes.dismiss()
    }
    // 닫은 뒤 다시 열면 새 기수 보드를 띄운다.
    await store.send(.router(.routeAction(
      id: 1,
      action: .liveBoard(.delegate(.bearerBoardRequested(festivalID: "fst", flagID: "flg_1", userID: "usr_me")))
    ))) {
      $0.routes.presentCover(.bearerBoard(.init(festivalID: "fst", flagID: "flg_1", viewerUserID: "usr_me")))
    }
  }

  @Test("계정이 바뀌면 열린 기수 보드를 닫는다")
  func accountChangeClosesBearerBoard() {
    var state = liveBoardState()
    state.routes.presentCover(.bearerBoard(.init(festivalID: "fst", flagID: "flg_1", viewerUserID: "usr_me")))

    state.clearAccountData()

    #expect(state.routes.count == 2)
    #expect(!state.routes.contains { $0.screen.is(\.bearerBoard) })
  }
}
