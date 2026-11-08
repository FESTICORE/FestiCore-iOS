//
//  BearerPlanPickFeatureTests.swift
//  BearerTests
//
//  Created by FestiCore on 11/8/26.
//

import BearerDomainInterface
import ComposableArchitecture
import Foundation
import Testing
@testable import Bearer

@MainActor
struct BearerPlanPickFeatureTests {
  /// 8/7(금) 17:00·19:00, 8/8(토) 17:00 KST
  private let sets = [
    BearerSet(
      id: "set_fri_2",
      artist: "실리카겔",
      stageName: "리벳 스테이지",
      startsAt: Date(timeIntervalSince1970: 1_786_096_800),
      endsAt: Date(timeIntervalSince1970: 1_786_100_400)
    ),
    BearerSet(
      id: "set_fri_1",
      artist: "새소년",
      stageName: "원더 스테이지",
      startsAt: Date(timeIntervalSince1970: 1_786_089_600),
      endsAt: Date(timeIntervalSince1970: 1_786_093_200)
    ),
    BearerSet(
      id: "set_sat_1",
      artist: "잔나비",
      stageName: "리벳 스테이지",
      startsAt: Date(timeIntervalSince1970: 1_786_176_000),
      endsAt: Date(timeIntervalSince1970: 1_786_179_600)
    ),
  ]

  @Test("공연을 서울 기준 날짜로 묶고 이미 고른 공연이 있는 날로 연다")
  func groupsDaysAndOpensPlannedDay() {
    let state = BearerPlanPickFeature.State(
      sets: sets,
      plan: ["set_sat_1"]
    )

    #expect(state.days.map(\.title) == [
      "8/7(금)",
      "8/8(토)"
    ])
    #expect(state.days.first?.sets.map(\.id) == [
      "set_fri_1",
      "set_fri_2"
    ])
    #expect(state.selectedDayIndex == 1)
  }

  @Test("공연을 눌러 고르고 빼며, 완료하면 시작 순으로 돌려준다")
  func togglesAndReturnsOrderedPlan() async {
    let store = TestStore(initialState: BearerPlanPickFeature.State(
      sets: sets,
      plan: []
    )) {
      BearerPlanPickFeature()
    }

    await store.send(.view(.setTapped("set_sat_1"))) { $0.selectedSetIDs = ["set_sat_1"] }
    await store.send(.view(.setTapped("set_fri_2"))) {
      $0.selectedSetIDs = [
        "set_sat_1",
        "set_fri_2"
      ]
    }
    await store.send(.view(.setTapped("set_fri_1"))) {
      $0.selectedSetIDs = [
        "set_sat_1",
        "set_fri_2",
        "set_fri_1"
      ]
    }
    await store.send(.view(.setTapped("set_fri_2"))) {
      $0.selectedSetIDs = [
        "set_sat_1",
        "set_fri_1"
      ]
    }
    await store.send(.view(.dayTapped(1))) { $0.selectedDayIndex = 1 }
    await store.send(.view(.dayTapped(5)))
    await store.send(.view(.doneTapped))
    await store.receive(.delegate(.picked([
      "set_fri_1",
      "set_sat_1"
    ])))
  }

  @Test("서버 한도 30개를 넘기면 고르지 않고 안내한다")
  func limitsToThirty() async {
    let plan = (1 ... 30).map { "old_\($0)" }
    let store = TestStore(initialState: BearerPlanPickFeature.State(
      sets: sets,
      plan: plan
    )) {
      BearerPlanPickFeature()
    }

    await store.send(.view(.setTapped("set_fri_1"))) {
      $0.limitMessage = "오늘 계획은 30개까지 고를 수 있어요."
    }
    await store.send(.view(.setTapped("old_1"))) {
      $0.selectedSetIDs.remove("old_1")
      $0.limitMessage = nil
    }
  }

  @Test("뒤로 가면 고르지 않고 닫는다")
  func backCloses() async {
    let store = TestStore(initialState: BearerPlanPickFeature.State(
      sets: sets,
      plan: []
    )) {
      BearerPlanPickFeature()
    }

    await store.send(.view(.backTapped))
    await store.receive(.delegate(.closeRequested))
  }
}
