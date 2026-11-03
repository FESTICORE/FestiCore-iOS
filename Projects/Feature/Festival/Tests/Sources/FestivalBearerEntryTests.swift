//
//  FestivalBearerEntryTests.swift
//  FestivalTests
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Testing
@testable import Festival

@MainActor
struct FestivalBearerEntryTests {
  private func state(hasSession: Bool, bearerFlagIDs: [String], boardFestivalID: String = "fst") -> FestivalFeature.State {
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.catalog = [FestivalCatalogItem(id: "fst", name: "원더리벳 2026", packVersion: 0)]
    state.hasSession = hasSession
    state.sessionUserID = hasSession ? "usr_me" : nil
    state.liveBoard = FestivalLiveBoardSnapshot(
      festivalID: boardFestivalID, activeFlags: [], followedFlags: [], crew: nil, bearerFlagIDs: bearerFlagIDs
    )
    return state
  }

  @Test("기수 깃발이 있는 로그인 사용자만 기수 버튼을 본다")
  func visibility() {
    #expect(state(hasSession: true, bearerFlagIDs: ["flg_1", "flg_2"]).bearerFlagID == "flg_1")
    #expect(state(hasSession: true, bearerFlagIDs: []).bearerFlagID == nil)
    #expect(state(hasSession: false, bearerFlagIDs: ["flg_1"]).bearerFlagID == nil)
    #expect(state(hasSession: true, bearerFlagIDs: ["flg_1"], boardFestivalID: "other").bearerFlagID == nil)
  }

  @Test("기수 버튼은 축제·깃발·사용자로 기수 보드를 요청한다")
  func requestsBoard() async {
    let store = TestStore(initialState: state(hasSession: true, bearerFlagIDs: ["flg_1"])) { FestivalFeature() }

    await store.send(.view(.bearerTapped))
    await store.receive(.delegate(.bearerBoardRequested(festivalID: "fst", flagID: "flg_1", userID: "usr_me")))
  }

  @Test("기수 깃발이 없으면 아무것도 하지 않는다")
  func ignoresWithoutFlag() async {
    let store = TestStore(initialState: state(hasSession: true, bearerFlagIDs: [])) { FestivalFeature() }
    await store.send(.view(.bearerTapped))
  }
}
