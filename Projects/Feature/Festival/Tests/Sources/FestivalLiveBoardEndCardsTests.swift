//
//  FestivalLiveBoardEndCardsTests.swift
//  FestivalTests
//
//  Created by FestiCore on 11/9/26.
//

import FestiCoreUtility
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

/// 라이브 보드 종료 직전 귀가 카드(E)와 종료 후 요약 카드(F)의 부분·잘못된 데이터 처리(#338)
@MainActor
struct FestivalLiveBoardEndCardsTests {
  @Test("귀가 카드는 빠졌거나 잘못된 시각을 출발편으로 고르지 않고, 탈 수 있는 편이 없으면 숨긴다")
  func homeRideSkipsMissingOrInvalidTimes() throws {
    let trainOnly = try #require(model(directions: .init(lastTrainAt: "2026-11-08T23:52:00+09:00")).homeRide(now: at("23:00")))
    #expect(trainOnly.remain == "막차까지 52분")
    #expect(trainOnly.shuttle == "셔틀 시간 미공개")
    #expect(trainOnly.train == "막차 23:52")

    let invalidTrain = try #require(model(directions: .init(
      lastShuttleAt: "2026-11-08T23:40:00+09:00",
      lastTrainAt: "막차 미정"
    )).homeRide(now: at("23:00")))
    #expect(invalidTrain.remain == "셔틀까지 40분")
    #expect(invalidTrain.shuttle == "마지막 셔틀 23:40")

    #expect(model(directions: .init(lastShuttleAt: "잘못된 시각")).homeRide(now: at("23:00")) == nil)
    #expect(model(directions: .init()).homeRide(now: at("23:00")) == nil)
    #expect(model(directions: .init(lastTrainAt: "2026-11-08T23:52:00+09:00")).homeRide(now: at("23:55")) == nil)
  }

  @Test("종료 요약의 본 공연은 마지막 공연일에 끝난 내 일정만 세고 다른 날·진행 중·잘못된 시각 공연은 뺀다")
  func doneSummaryCountsOnlyFinishedSetsOnLastDay() throws {
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(multiDayPackJSON.utf8)
    )
    state.hasSession = true
    state.mySchedule = .init(
      festivalID: "fst",
      setIDs: ["set_day1", "set_done", "set_playing", "set_bad"]
    )
    state.liveBoard = FestivalLiveBoardSnapshot(
      festivalID: "fst",
      activeFlags: [],
      followedFlags: [
        flag("flg_1"),
        flag("flg_2")
      ],
      crew: .init(
        id: "crw",
        name: "크루",
        members: [
          .init(
            id: "usr_me",
            nickname: "나",
            state: nil,
            zoneID: nil
          ),
          .init(
            id: "usr_friend",
            nickname: "친구",
            state: nil,
            zoneID: nil
          )
        ]
      )
    )
    let now = try #require("2026-10-21T21:30:00+09:00".isoDate)

    let summary = try #require(FestivalLiveBoardScreenModel(state: state).doneSummary(now: now))
    #expect(summary.seenSetCount == 1)
    #expect(summary.crewCount == 2)
    #expect(summary.followedFlagCount == 2)

    state.hasSession = false
    #expect(FestivalLiveBoardScreenModel(state: state).doneSummary(now: now) == nil)
  }
}

// MARK: - 고정 값

private extension FestivalLiveBoardEndCardsTests {
  func model(directions: FestivalPackDetail.Directions) -> FestivalLiveBoardScreenModel {
    var state = FestivalFeature.State(selectedFestivalID: "fst")
    state.selectedPack = try? JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst","name":"원더리벳 2026"}"#.utf8)
    )
    state.homeDetails = .loaded(
      "fst",
      directions
    )
    return FestivalLiveBoardScreenModel(state: state)
  }

  func at(_ time: String) -> Date {
    return "2026-11-08T\(time):00+09:00".isoDate ?? .distantPast
  }

  func flag(_ id: String) -> FestivalLiveBoardSnapshot.Flag {
    return .init(
      id: id,
      name: id,
      status: "active",
      zoneID: nil,
      activity: nil,
      thumbnailURL: nil
    )
  }
}

/// 이틀 축제. 둘째 날 21:30 기준으로 첫날 공연, 끝난 공연, 진행 중 공연, 시각이 잘못된 공연, 내 일정이 아닌 공연이 섞여 있다.
private let multiDayPackJSON = #"""
  {"id":"fst","name":"이틀 축제",
  "days":[
    {"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00","endsAt":"2026-10-20T23:00:00+09:00"},
    {"date":"2026-10-21","startsAt":"2026-10-21T12:00:00+09:00","endsAt":"2026-10-21T22:30:00+09:00"}
  ],
  "stages":[{"id":"stg_main","name":"메인"}],
  "sets":[
    {"id":"set_day1","stageId":"stg_main","artist":"첫날","startsAt":"2026-10-20T19:00:00+09:00","endsAt":"2026-10-20T20:00:00+09:00"},
    {"id":"set_done","stageId":"stg_main","artist":"끝난 공연","startsAt":"2026-10-21T19:00:00+09:00","endsAt":"2026-10-21T20:00:00+09:00"},
    {"id":"set_other","stageId":"stg_main","artist":"남의 공연","startsAt":"2026-10-21T20:00:00+09:00","endsAt":"2026-10-21T21:00:00+09:00"},
    {"id":"set_playing","stageId":"stg_main","artist":"진행 중","startsAt":"2026-10-21T21:00:00+09:00","endsAt":"2026-10-21T22:00:00+09:00"},
    {"id":"set_bad","stageId":"stg_main","artist":"잘못된 시각","startsAt":"어제 저녁","endsAt":"2026-10-21T18:00:00+09:00"}
  ]}
  """#
