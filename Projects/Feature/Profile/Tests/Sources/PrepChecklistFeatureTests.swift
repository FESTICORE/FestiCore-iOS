//
//  PrepChecklistFeatureTests.swift
//  ProfileTests
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import Testing
@testable import Profile

/// 준비 안내 3단계(S15-③): 팩 상세 준비물을 쓰고 단계 이동만 부모에게 맡긴다.
@MainActor
struct PrepChecklistFeatureTests {
  @Test("준비물 탭으로 시작한다")
  func startsOnChecklist() {
    let state = PrepChecklistFeature.State(
      festivalID: "festival",
      title: "원더리벳 2026"
    )
    #expect(state.detail.tab == .checklist)
    #expect(state.detail.title == "원더리벳 2026")
  }

  @Test("준비 완료·건너뛰기는 끝, 나중에는 안내 전체를 미룬다")
  func delegates() async {
    let store = TestStore(initialState: PrepChecklistFeature.State(
      festivalID: "festival",
      title: "원더리벳 2026"
    )) {
      PrepChecklistFeature()
    }

    await store.send(.view(.doneTapped))
    await store.receive(.delegate(.finished))
    await store.send(.view(.skipTapped))
    await store.receive(.delegate(.finished))
    await store.send(.view(.laterTapped))
    await store.receive(.delegate(.later))
  }

  @Test("내 항목 입력은 팩 상세 입력값으로 넘긴다")
  func newItemText() async {
    let store = TestStore(initialState: PrepChecklistFeature.State(
      festivalID: "festival",
      title: "원더리벳 2026"
    )) {
      PrepChecklistFeature()
    }

    await store.send(.view(.newItemTextChanged("보조배터리")))
    await store.receive(.detail(.binding(.set(
      \.newItemText,
      "보조배터리"
    )))) {
      $0.detail.newItemText = "보조배터리"
    }
  }
}
