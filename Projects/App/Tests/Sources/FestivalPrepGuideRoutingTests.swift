//
//  FestivalPrepGuideRoutingTests.swift
//  FestiCoreTests
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
import TCAFlow
@testable import FestiCore

/// 준비 안내(S15): S00 목록에서 처음 받은 팩 → ①내 일정 → ②깃발 팔로우. 시안 Row A 준비 흐름.
@MainActor
struct FestivalPrepGuideRoutingTests {
  private let packJSON = #"{"id":"festival","name":"원더리벳 2026","days":[{"date":"2026-10-17"}],"stages":[{"id":"stage","name":"메인"}],"zones":[{"id":"zone_a","name":"리벳 앞"}],"timetable":[{"id":"set_1","artist":"새소년","stageId":"stage","startsAt":"2026-10-17T18:00:00+09:00","endsAt":"2026-10-17T19:00:00+09:00"}]}"#

  private func listState() -> FestivalCoordinator.State {
    var state = FestivalCoordinator.State()
    guard case var .festivalList(list) = state.routes[0].screen else { return state }
    list.hasSession = true
    list.cachedPacks["festival"] = CachedFestivalPack(
      festivalID: "festival",
      packVersion: 1,
      etag: "v1",
      pack: Data(packJSON.utf8)
    )
    state.routes[0].screen = .festivalList(list)
    return state
  }

  @Test("처음 받은 팩은 서버 내 일정으로 1단계를 열고, 저장하면 2단계로 가며 타임테이블에 알린다")
  func opensScheduleThenFlags() async {
    let store = TestStore(initialState: listState()) {
      FestivalCoordinator()
    } withDependencies: {
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(mySchedule: { _ throws(FestivalScheduleError) in
        return FestivalSchedule(setIDs: ["set_1"])
      })
    }
    store.exhaustivity = .off

    await store.send(.router(.routeAction(
      id: 0,
      action: .festivalList(.delegate(.prepGuideRequested(festivalID: "festival")))
    )))
    await store.receive(\.prepScheduleLoaded)
    let pick = store.state.routes.last?.screen.prepSchedule
    #expect(pick?.festivalID == "festival")
    #expect(pick?.selectedSetIDs == ["set_1"])
    #expect(pick?.days.flatMap(\.sets).map(\.id) == ["set_1"])

    await store.send(.router(.routeAction(
      id: 1,
      action: .prepSchedule(.delegate(.saved(
        festivalID: "festival",
        setIDs: ["set_1"]
      )))
    )))
    await store.receive { action in
      guard case .delegate(.prepScheduleSaved(
        festivalID: "festival",
        setIDs: ["set_1"]
      )) = action else { return false }
      return true
    }
    #expect(store.state.routes.count == 3)
    #expect(store.state.routes.last?.screen.prepFlags?.flag.festivalID == "festival")
    #expect(store.state.routes.last?.screen.prepFlags?.flag.directory.zoneNames == ["zone_a": "리벳 앞"])

    await store.send(.router(.routeAction(
      id: 2,
      action: .prepFlags(.delegate(.finished))
    )))
    #expect(store.state.routes.count == 4)
    #expect(store.state.routes.last?.screen.prepChecklist?.detail.festivalID == "festival")
    #expect(store.state.routes.last?.screen.prepChecklist?.detail.title == "원더리벳 2026")
    #expect(store.state.routes.last?.screen.prepChecklist?.detail.tab == .checklist)

    await store.send(.router(.routeAction(
      id: 3,
      action: .prepChecklist(.delegate(.finished))
    )))
    #expect(store.state.routes.count == 1)
    #expect(!store.state.isPrepGuideOpen)
  }

  @Test("서버 내 일정을 읽지 못하면 덮어쓰지 않게 1단계를 건너뛰고 2단계부터 연다")
  func skipsScheduleWhenUnavailable() async {
    let store = TestStore(initialState: listState()) {
      FestivalCoordinator()
    } withDependencies: {
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(mySchedule: { _ throws(FestivalScheduleError) in
        throw .unavailable
      })
    }
    store.exhaustivity = .off

    await store.send(.router(.routeAction(
      id: 0,
      action: .festivalList(.delegate(.prepGuideRequested(festivalID: "festival")))
    )))
    await store.receive(\.prepScheduleLoaded)
    #expect(store.state.routes.count == 2)
    #expect(store.state.routes.last?.screen.is(\.prepFlags) == true)
  }

  @Test("나중에 할게요는 준비 안내를 모두 닫고, 깃발 팔로우 로그인은 위로 올린다")
  func laterClosesAndLoginBubbles() async {
    var state = listState()
    state.routes.push(.prepFlags(FestivalPrepFlagsFeature.State(festivalID: "festival")))
    let store = TestStore(initialState: state) { FestivalCoordinator() }
    store.exhaustivity = .off

    await store.send(.router(.routeAction(
      id: 1,
      action: .prepFlags(.delegate(.loginRequested))
    )))
    await store.receive { action in
      guard case .delegate(.followLoginRequested) = action else { return false }
      return true
    }

    await store.send(.router(.routeAction(
      id: 1,
      action: .prepFlags(.delegate(.later))
    )))
    #expect(store.state.routes.count == 1)
  }

  @Test("준비 안내 화면에서는 탭바를 숨긴다")
  func hidesTabBar() {
    var state = MainTabCoordinator.State()
    state.festivalState.routes.push(.prepFlags(FestivalPrepFlagsFeature.State(festivalID: "festival")))
    #expect(state.isCrewOnTop)
    #expect(state.shouldHideTabBar)
  }
}
