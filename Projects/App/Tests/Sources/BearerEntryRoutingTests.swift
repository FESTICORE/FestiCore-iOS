//
//  BearerEntryRoutingTests.swift
//  FestiCoreTests
//
//  Created by FestiCore on 11/8/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import Foundation
import Testing
import TCAFlow
@testable import FestiCore

/// 마이 '기수이신가요?' → 기수 인증(S13 F~I) → 깃발 프로필(S10) → 기수 보드
@MainActor
struct BearerEntryRoutingTests {
  private let claim = BearerClaim(
    flagID: "flg_1",
    profile: BearerFlagProfile(
      id: "flg_1",
      name: "새 깃발"
    ),
    isNew: true,
    coBearerIDs: []
  )

  private func loggedInState() -> MainTabCoordinator.State {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.authFlow.hasSession = true
    state.authFlow.verifiedUserID = "usr_me"
    return state
  }

  @Test("라이브 탭에서 연 페스티벌로 기수 인증 화면을 연다")
  func opensClaimForLiveFestival() async {
    var state = loggedInState()
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "fst_live")))
    state.profileState.packs = [
      FestivalReceivedPack(
        id: "fst_pack",
        name: "다른 페스티벌",
        packVersion: 1
      )
    ]

    let store = TestStore(initialState: state) { MainTabCoordinator() }
    // 인증 화면 상태는 만든 시각(now)을 들고 있어 값 전체 대신 필요한 값만 비교한다.
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.profile(.delegate(.bearerRequested))))
    #expect(store.state.bearerEntry?.festivalID == "fst_live")
    #expect(store.state.bearerEntry?.viewerUserID == "usr_me")
    #expect(store.state.bearerEntry?.routes.first?.screen.claim?.festivalID == "fst_live")
  }

  @Test("라이브 보드가 없으면 받은 팩이 하나일 때 그 페스티벌로 연다")
  func usesSingleReceivedPack() async {
    var state = loggedInState()
    state.profileState.packs = [
      FestivalReceivedPack(
        id: "fst_pack",
        name: "원더리벳 2026",
        packVersion: 1
      )
    ]

    let store = TestStore(initialState: state) { MainTabCoordinator() }
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.profile(.delegate(.bearerRequested))))
    #expect(store.state.bearerEntry?.festivalID == "fst_pack")
  }

  @Test("어느 페스티벌인지 모르면 열지 않고 안내한다")
  func asksToOpenFestivalWhenAmbiguous() async {
    var state = loggedInState()
    state.profileState.packs = [
      FestivalReceivedPack(
        id: "fst_a",
        name: "A",
        packVersion: 1
      ),
      FestivalReceivedPack(
        id: "fst_b",
        name: "B",
        packVersion: 1
      ),
    ]

    let store = TestStore(initialState: state) { MainTabCoordinator() }

    await store.send(.profileCoordinator(.profile(.delegate(.bearerRequested)))) {
      $0.profileState.destination = .alert(.alert(
        title: "페스티벌을 먼저 열어 주세요",
        message: "기수 코드는 페스티벌마다 달라요. 라이브 탭에서 기수로 참여할 페스티벌을 연 뒤 다시 눌러 주세요.",
        confirmTitle: "확인",
        cancelTitle: "닫기"
      ))
    }
    #expect(store.state.bearerEntry == nil)
  }

  @Test("로그인하지 않았으면 로그인을 요청한다")
  func requestsLoginWithoutSession() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "fst_live")))
    let store = TestStore(initialState: state) { MainTabCoordinator() }

    await store.send(.profileCoordinator(.profile(.delegate(.bearerRequested))))
    await store.receive { action in
      guard case .auth(.view(.loginRequested(.none))) = action else { return false }
      return true
    } assert: {
      $0.authFlow.generation = 1
      $0.authFlow.presentation = .login
    }
  }

  @Test("코드가 맞으면 깃발 프로필, 저장을 마치면 기수 보드로 간다")
  func claimThenProfileThenBoard() {
    var state = BearerEntryCoordinator.State(
      festivalID: "fst",
      viewerUserID: "usr_me"
    )
    let coordinator = BearerEntryCoordinator()

    _ = coordinator.handleRoute(
      state: &state,
      action: .router(.routeAction(
        id: 0,
        action: .claim(.delegate(.claimed(
          festivalID: "fst",
          claim: claim
        )))
      ))
    )
    #expect(state.routes.count == 2)
    let profile = state.routes.last?.screen.profile
    #expect(profile?.flagID == "flg_1")
    #expect(profile?.isNewBearer == true)
    #expect(profile?.name == "새 깃발")

    _ = coordinator.handleRoute(
      state: &state,
      action: .router(.routeAction(
        id: 1,
        action: .profile(.delegate(.finished(flagID: "flg_1")))
      ))
    )
    #expect(state.routes.count == 3)
    #expect(state.routes.last?.screen.board == BearerBoardFeature.State(
      festivalID: "fst",
      flagID: "flg_1",
      viewerUserID: "usr_me"
    ))
  }

  @Test("오늘 계획은 팩 공연으로 고르기 화면을 열고, 고르면 닫고 프로필에 넣는다")
  func planPickFillsProfile() async {
    let set = BearerSet(
      id: "set_1",
      artist: "새소년",
      stageName: "원더 스테이지",
      startsAt: Date(timeIntervalSince1970: 1_786_089_600),
      endsAt: Date(timeIntervalSince1970: 1_786_093_200)
    )
    var profile = BearerProfileFeature.State(
      festivalID: "fst",
      flagID: "flg_1",
      profile: claim.profile,
      isNewBearer: true
    )
    profile.sets = [set]
    var state = BearerEntryCoordinator.State(
      festivalID: "fst",
      viewerUserID: "usr_me"
    )
    state.routes.push(.profile(profile))
    let store = TestStore(initialState: state) { BearerEntryCoordinator() }

    await store.send(.router(.routeAction(
      id: 1,
      action: .profile(.view(.planTapped))
    )))
    await store.receive({ action in
      guard case .router(.routeAction(
        id: 1,
        action: .profile(.delegate(.planRequested))
      )) = action else { return false }
      return true
    }) {
      $0.routes.push(.planPick(BearerPlanPickFeature.State(
        sets: [set],
        plan: []
      )))
    }

    await store.send(.router(.routeAction(
      id: 2,
      action: .planPick(.delegate(.picked(["set_1"])))
    ))) {
      $0.routes.removeAll { $0.screen.is(\.planPick) }
    }
    await store.receive({ action in
      guard case .router(.routeAction(
        id: 1,
        action: .profile(.view(.planChanged))
      )) = action else { return false }
      return true
    }) {
      $0.routes[1].screen.modify(\.profile) {
        $0.plan = ["set_1"]
        $0.isPlanEdited = true
      }
    }
  }

  @Test("인증·프로필·보드에서 닫으면 흐름을 닫는다")
  func closeRequestsDismissFlow() async {
    var state = loggedInState()
    state.bearerEntry = BearerEntryCoordinator.State(
      festivalID: "fst",
      viewerUserID: "usr_me"
    )
    let store = TestStore(initialState: state) { MainTabCoordinator() }

    await store.send(.bearerEntry(.presented(.router(.routeAction(
      id: 0,
      action: .claim(.delegate(.closeRequested))
    )))))
    await store.receive({ action in
      guard case .bearerEntry(.presented(.delegate(.closeRequested))) = action else { return false }
      return true
    }) {
      $0.bearerEntry = nil
    }
  }
}
