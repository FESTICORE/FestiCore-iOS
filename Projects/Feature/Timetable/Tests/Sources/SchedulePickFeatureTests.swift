//
//  SchedulePickFeatureTests.swift
//  TimetableTests
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Timetable

@MainActor
struct SchedulePickFeatureTests {
  @Test func tappingSetTogglesSelection() async {
    let store = TestStore(initialState: Self.state()) { SchedulePickFeature() }

    await store.send(.view(.setTapped("saucy"))) {
      $0.selectedSetIDs = ["saucy"]
    }
    await store.send(.view(.setTapped("saucy"))) {
      $0.selectedSetIDs = []
    }
  }

  @Test func nextSavesSelectionAsMyScheduleAndReportsSaved() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let saved = LockIsolated<[(String, [String], Date)]>([])
    var state = Self.state()
    state.selectedSetIDs = ["spyair", "coldrain"]
    let store = TestStore(initialState: state) {
      SchedulePickFeature()
    } withDependencies: {
      $0.date.now = now
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(
        saveMySchedule: { festivalID, setIDs, clientAt throws(FestivalScheduleError) in
          saved.withValue { $0.append((festivalID, setIDs, clientAt)) }
          return FestivalSchedule(setIDs: setIDs)
        }
      )
    }

    await store.send(.view(.nextTapped)) {
      $0.isSaving = true
    }
    await store.receive(\.async.save)
    await store.receive(\.inner.saveSucceeded) {
      $0.isSaving = false
    }
    await store.receive(\.delegate.saved)
    #expect(saved.value.count == 1)
    #expect(saved.value.first?.0 == "festival")
    #expect(saved.value.first?.1 == ["coldrain", "spyair"])
    #expect(saved.value.first?.2 == now)
  }

  @Test func nextWithoutSelectionDoesNothing() async {
    let store = TestStore(initialState: Self.state()) { SchedulePickFeature() }

    await store.send(.view(.nextTapped))
  }

  @Test func failedSaveKeepsSelectionAndShowsMessage() async {
    var state = Self.state()
    state.selectedSetIDs = ["natori"]
    let store = TestStore(initialState: state) {
      SchedulePickFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(
        saveMySchedule: { _, _, _ throws(FestivalScheduleError) in throw .unavailable }
      )
    }

    await store.send(.view(.nextTapped)) {
      $0.isSaving = true
    }
    await store.receive(\.async.save)
    await store.receive(\.inner.saveFailed) {
      $0.isSaving = false
      $0.errorMessage = "내 일정을 저장하지 못했어요. 다시 시도해 주세요."
    }
  }

  @Test func staleSaveShowsNewerServerSchedule() async {
    var state = Self.state()
    state.selectedSetIDs = ["natori"]
    let store = TestStore(initialState: state) {
      SchedulePickFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(
        saveMySchedule: { _, _, _ throws(FestivalScheduleError) in
          throw .stale(FestivalSchedule(setIDs: ["saucy"]))
        }
      )
    }

    await store.send(.view(.nextTapped)) {
      $0.isSaving = true
    }
    await store.receive(\.async.save)
    await store.receive(\.inner.saveFailed) {
      $0.isSaving = false
      $0.selectedSetIDs = ["saucy"]
      $0.errorMessage = "다른 기기에서 바뀐 일정을 불러왔어요. 확인하고 다시 눌러 주세요."
    }
  }

  @Test func skipAndLaterReportToParent() async {
    let store = TestStore(initialState: Self.state()) { SchedulePickFeature() }

    await store.send(.view(.skipTapped))
    await store.receive(\.delegate.skipped)
    await store.send(.view(.laterTapped))
    await store.receive(\.delegate.later)
  }

  @Test func dayTapChangesDayWithinRange() async {
    let store = TestStore(initialState: Self.state()) { SchedulePickFeature() }

    await store.send(.view(.dayTapped(1))) {
      $0.selectedDayIndex = 1
    }
    await store.send(.view(.dayTapped(5)))
  }

  @Test func overlapNamesEarlierSelectedSetAndSharedMinutes() {
    var state = Self.state()
    state.selectedSetIDs = ["coldrain", "spyair"]
    let day = state.days[0]
    let spyair = day.sets.first { $0.id == "spyair" }!
    let coldrain = day.sets.first { $0.id == "coldrain" }!

    #expect(state.overlap(of: spyair)?.artist == "coldrain")
    #expect(state.overlap(of: spyair)?.minutes == 20)
    #expect(state.overlap(of: coldrain) == nil)
  }

  @Test func particleFollowsLastHangulSyllable() {
    #expect(SchedulePickView.withParticle("새벽세시밴드") == "와")
    #expect(SchedulePickView.withParticle("소음주의보") == "와")
    #expect(SchedulePickView.withParticle("호락호락") == "과")
    #expect(SchedulePickView.withParticle("coldrain") == "과")
    #expect(SchedulePickView.clock(25 * 60 + 5) == "01:05")
  }

  /// Figma S15-1 예시 공연. 시각은 그날 0시부터의 분이다.
  static func state() -> SchedulePickFeature.State {
    let stages = [
      TimetableStage(id: "livet", name: "LIVET STAGE"),
      TimetableStage(id: "wonder", name: "WONDER STAGE"),
    ]
    let first = TimetableDay(
      id: "day1",
      title: "11/20 금",
      date: Date(timeIntervalSince1970: 1_795_100_400),
      stages: stages,
      sets: [
        TimetableSet(id: "saucy", artist: "Saucy Dog", stageID: "livet", start: 930, end: 980),
        TimetableSet(id: "coldrain", artist: "coldrain", stageID: "wonder", start: 1000, end: 1050),
        TimetableSet(id: "spyair", artist: "SPYAIR", stageID: "livet", start: 1030, end: 1080),
        TimetableSet(id: "natori", artist: "natori", stageID: "wonder", start: 1100, end: 1160),
      ]
    )
    let second = TimetableDay(id: "day2", title: "11/21 토", date: Date(timeIntervalSince1970: 1_795_186_800), stages: stages, sets: [])
    return SchedulePickFeature.State(festivalID: "festival", days: [first, second])
  }
}
