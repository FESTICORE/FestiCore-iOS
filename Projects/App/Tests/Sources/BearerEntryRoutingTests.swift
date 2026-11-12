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

  @Test("라이브 탭에서 연 페스티벌을 먼저 고른 코드 없는 깃발 등록(S14 D)을 연다")
  func opensRegisterForLiveFestival() async {
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
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.profile(.delegate(.bearerRequested))))
    #expect(store.state.bearerEntry?.festivalID == nil)
    #expect(store.state.bearerEntry?.viewerUserID == "usr_me")
    #expect(store.state.bearerEntry?.routes.first?.screen.register?.preferredFestivalID == "fst_live")
  }

  @Test("라이브 보드가 없으면 받은 팩이 하나일 때 그 페스티벌을 먼저 고른다")
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
    #expect(store.state.bearerEntry?.routes.first?.screen.register?.preferredFestivalID == "fst_pack")
  }

  @Test("어느 페스티벌인지 모르면 미리 고르지 않고 등록 화면에서 고르게 한다")
  func opensRegisterWithoutPreferredFestival() async {
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
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.profile(.delegate(.bearerRequested))))
    #expect(store.state.profileState.destination == nil)
    #expect(store.state.bearerEntry?.routes.first?.screen.register?.preferredFestivalID == nil)
    #expect(store.state.bearerEntry?.routes.first?.screen.is(\.register) == true)
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
    // 마이 화면이 로그인 상태를 받기 전이라 내 깃발은 읽지 않는다.
    await store.receive(\.profileCoordinator.profile.view.bearerFlagsRefreshRequested)
  }

  @Test("마이 내 깃발 줄은 프로필 수정, 기수 보드 열기는 보드를 바로 연다")
  func myFlagOpensProfileOrBoard() async {
    let store = TestStore(initialState: loggedInState()) { MainTabCoordinator() }
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.profile(.delegate(.bearerProfileRequested(
      festivalID: "fst_1",
      flagID: "flg_1"
    )))))
    #expect(store.state.bearerEntry?.festivalID == "fst_1")
    #expect(store.state.bearerEntry?.routes.first?.screen.profile?.flagID == "flg_1")

    await store.send(.profileCoordinator(.profile(.delegate(.bearerBoardRequested(
      festivalID: "fst_1",
      flagID: "flg_1"
    )))))
    #expect(store.state.bearerEntry?.routes.first?.screen.board?.flagID == "flg_1")
  }

  @Test("가입 직후 기수 여부에서 기수를 고르면 등록 화면, 관객이면 흐름을 닫는다")
  func roleChoiceRoutes() async {
    let state = BearerEntryCoordinator.State(
      registerPreferredFestivalID: "fst_pin",
      viewerUserID: "usr_me",
      asksRole: true
    )
    #expect(state.routes.first?.screen.is(\.roleChoice) == true)
    let store = TestStore(initialState: state) { BearerEntryCoordinator() }

    await store.send(.router(.routeAction(
      id: 0,
      action: .roleChoice(.delegate(.bearerChosen))
    ))) {
      $0.routes.push(.register(BearerRegisterFeature.State(preferredFestivalID: "fst_pin")))
    }
    await store.send(.router(.routeAction(
      id: 0,
      action: .roleChoice(.delegate(.audienceChosen))
    )))
    await store.receive(\.delegate.closeRequested)
  }

  @Test("코드 없이 깃발을 만들면 그 페스티벌 핀을 부모에 요청하고 팩 받기도 넘긴다")
  func registeredRequestsPin() async {
    let state = BearerEntryCoordinator.State(
      registerPreferredFestivalID: nil,
      viewerUserID: "usr_me",
      asksRole: false
    )
    let store = TestStore(initialState: state) { BearerEntryCoordinator() }

    await store.send(.router(.routeAction(
      id: 0,
      action: .register(.delegate(.registered(
        flagID: "flg_9",
        festivalID: "fst_9"
      )))
    ))) {
      $0.festivalID = "fst_9"
    }
    await store.receive(\.delegate.festivalPinRequested)
    await store.send(.router(.routeAction(
      id: 0,
      action: .register(.delegate(.packRequested(festivalID: "fst_9")))
    )))
    await store.receive(\.delegate.packRequested)
  }

  @Test("등록 화면의 초대 코드는 코드 인증을 열고, 뒤로 가면 등록 화면으로 돌아간다")
  func claimFromRegisterGoesBack() async {
    let state = BearerEntryCoordinator.State(
      registerPreferredFestivalID: nil,
      viewerUserID: "usr_me",
      asksRole: false
    )
    let store = TestStore(initialState: state) { BearerEntryCoordinator() }
    store.exhaustivity = .off

    await store.send(.router(.routeAction(
      id: 0,
      action: .register(.delegate(.claimRequested(festivalID: "fst_1")))
    )))
    #expect(store.state.festivalID == "fst_1")
    #expect(store.state.routes.last?.screen.claim?.festivalID == "fst_1")
    await store.send(.router(.routeAction(
      id: 1,
      action: .claim(.delegate(.closeRequested))
    )))
    #expect(store.state.routes.count == 1)
    #expect(store.state.routes.first?.screen.is(\.register) == true)
  }

  @Test("마이 탭은 핀 요청을 라이브 탭 페스티벌 선택으로 넘긴다")
  func pinRequestSelectsFestival() async {
    var state = loggedInState()
    state.bearerEntry = BearerEntryCoordinator.State(
      registerPreferredFestivalID: nil,
      viewerUserID: "usr_me",
      asksRole: false
    )
    let store = TestStore(initialState: state) { MainTabCoordinator() }
    store.exhaustivity = .off

    await store.send(.bearerEntry(.presented(.delegate(.festivalPinRequested("fst_9")))))
    await store.receive { action in
      guard case .festival(.pinFestival("fst_9")) = action else { return false }
      return true
    }
    #expect(store.state.bearerEntry != nil)
  }

  @Test("가입을 마치면 기수 여부(S14 C)부터 여는 등록 흐름을 띄운다")
  func signUpCompletedAsksRole() async {
    var state = loggedInState()
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "fst_live")))
    let store = TestStore(initialState: state) { MainTabCoordinator() }
    store.exhaustivity = .off

    await store.send(.session(.delegate(.signUpCompleted)))
    #expect(store.state.bearerEntry?.routes.first?.screen.is(\.roleChoice) == true)
    #expect(store.state.bearerEntry?.preferredFestivalID == "fst_live")
  }
}
