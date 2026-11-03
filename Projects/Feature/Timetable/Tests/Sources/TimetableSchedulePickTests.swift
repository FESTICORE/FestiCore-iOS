//
//  TimetableSchedulePickTests.swift
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
struct TimetableSchedulePickTests {
  /// 샘플 첫날(2026-08-07 KST) 전날 정오
  private let now = Date(timeIntervalSince1970: 1_786_028_400 - 12 * 60 * 60)

  @Test func tappingButtonOpensSchedulePickWithMySchedule() async {
    let store = makeStore(readyState(mine: ["lime"]), save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("열기만 해서는 저장하지 않아야 한다")
      throw .unavailable
    })

    await store.send(.view(.schedulePickTapped)) {
      $0.destination = .schedulePick(SchedulePickFeature.State(
        festivalID: "fst",
        days: $0.days,
        selectedSetIDs: ["lime"]
      ))
    }
  }

  @Test func tappingButtonWhileLoadingScheduleDoesNotOpen() async {
    var state = readyState()
    state.scheduleSync = .loading
    let store = makeStore(state, save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("열리지 않았으니 저장하지 않아야 한다")
      throw .unavailable
    })

    await store.send(.view(.schedulePickTapped))
  }

  @Test func tappingButtonWhileSavingOrLocalOnlyDoesNotOpen() async {
    var saving = readyState()
    saving.isSaving = true
    var localOnly = readyState()
    localOnly.scheduleSync = .localOnly
    for state in [saving, localOnly] {
      let store = makeStore(state, save: { _, _, _ throws(FestivalScheduleError) in
        Issue.record("열리지 않았으니 저장하지 않아야 한다")
        throw .unavailable
      })

      await store.send(.view(.schedulePickTapped))
    }
  }

  @Test func tappingButtonTwiceKeepsFirstPick() async {
    let store = makeStore(readyState(), save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("열기만 해서는 저장하지 않아야 한다")
      throw .unavailable
    })

    await store.send(.view(.schedulePickTapped)) {
      $0.destination = .schedulePick(SchedulePickFeature.State(festivalID: "fst", days: $0.days))
    }
    await store.send(.destination(.presented(.schedulePick(.view(.setTapped("lime")))))) {
      $0.destination?.modify(\.schedulePick) { $0.selectedSetIDs = ["lime"] }
    }
    await store.send(.view(.schedulePickTapped))
  }

  @Test func pickSaveIsLaterThanPreviousSave() async {
    let previous = now.addingTimeInterval(60)
    var state = readyState()
    state.lastClientAt = previous
    let clientAts = LockIsolated<[Date]>([])
    let store = makeStore(opened(state), save: { _, setIDs, clientAt throws(FestivalScheduleError) in
      clientAts.withValue { $0.append(clientAt) }
      return FestivalSchedule(setIDs: setIDs)
    })
    store.exhaustivity = .off

    await store.send(.destination(.presented(.schedulePick(.view(.setTapped("lime"))))))
    await store.send(.destination(.presented(.schedulePick(.view(.nextTapped)))))
    await store.receive(\.delegate.scheduleSaved)

    #expect(clientAts.value == [previous.addingTimeInterval(0.001)])
    // 타임테이블의 다음 저장은 이 시각보다 1ms 이상 늦게 보낸다.
    #expect(store.state.lastClientAt == previous.addingTimeInterval(0.001))
  }

  @Test func lateTimetableSaveAfterPickSaveIsIgnored() async {
    var state = readyState()
    state.isSaving = true
    state.needsSave = true
    let inFlight = TimetableFeature.ScheduleSave(setIDs: [], clientAt: now, generation: 0)
    let store = makeStore(opened(state), save: { _, setIDs, _ throws(FestivalScheduleError) in
      FestivalSchedule(setIDs: setIDs)
    })

    await store.send(.destination(.presented(.schedulePick(.view(.setTapped("lime")))))) {
      $0.destination?.modify(\.schedulePick) { $0.selectedSetIDs = ["lime"] }
    }
    await store.send(.destination(.presented(.schedulePick(.view(.nextTapped))))) {
      $0.destination?.modify(\.schedulePick) { $0.isSaving = true }
    }
    await store.receive(\.destination.presented.schedulePick.async.save)
    await store.receive(\.destination.presented.schedulePick.inner.saveSucceeded) {
      $0.destination?.modify(\.schedulePick) { $0.isSaving = false }
    }
    await store.receive(\.destination.presented.schedulePick.delegate.saved) {
      $0.destination = nil
      $0.mySetIDs = ["lime"]
      $0.isSaving = false
      $0.needsSave = false
      $0.lastClientAt = now
    }
    await store.receive(\.delegate.scheduleSaved)

    // 일정 고르기 전에 보낸 타임테이블 저장의 응답이 늦게 와도 목록과 delegate가 바뀌지 않는다.
    await store.send(.inner(.scheduleSaved(festivalID: "fst", inFlight, .success(FestivalSchedule(setIDs: [])))))
  }

  @Test func packUpdateWhilePickIsOpenClosesIt() async {
    let store = makeStore(opened(readyState(mine: ["lime"])), save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("팩 갱신으로 닫히면 저장하지 않아야 한다")
      throw .unavailable
    })

    await store.send(.view(.packUpdated)) {
      $0.destination = nil
    }
  }

  @Test func appearingWhilePickIsOpenDoesNotReloadOrSave() async {
    var state = readyState()
    state.uncertainSave = TimetableFeature.ScheduleSave(setIDs: [], clientAt: now, generation: 0)
    let store = makeStore(opened(state), save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("일정 고르기가 열려 있으면 타임테이블이 저장하지 않아야 한다")
      throw .unavailable
    })

    await store.send(.view(.timetableAppeared))
  }

  @Test func accountOrFestivalChangeWhilePickIsSavingDropsResponse() async {
    for change in [TimetableFeature.Action.view(.accountChanged), .view(.festivalChanged("next"))] {
      let clock = TestClock()
      let store = makeStore(opened(readyState()), save: { _, setIDs, _ throws(FestivalScheduleError) in
        try? await clock.sleep(for: .seconds(1))
        return FestivalSchedule(setIDs: setIDs)
      }, fetch: { _ throws(FestivalScheduleError) in
        FestivalSchedule(setIDs: [])
      })
      store.exhaustivity = .off

      await store.send(.destination(.presented(.schedulePick(.view(.setTapped("lime"))))))
      await store.send(.destination(.presented(.schedulePick(.view(.nextTapped)))))
      await store.receive(\.destination.presented.schedulePick.async.save)
      await store.send(change) {
        $0.destination = nil
      }
      await store.receive(\.inner.scheduleLoaded)
      // 취소된 저장의 대기를 끝내도 응답이 들어오지 않는다.
      await clock.run()

      #expect(store.state.destination == nil)
      #expect(store.state.mySetIDs.isEmpty)
    }
  }

  @Test func savingClosesPickAndRefreshesMySchedule() async {
    let saved = LockIsolated<[(festivalID: String, setIDs: [String], clientAt: Date)]>([])
    let store = makeStore(opened(readyState()), save: { festivalID, setIDs, clientAt throws(FestivalScheduleError) in
      saved.withValue { $0.append((festivalID, setIDs, clientAt)) }
      return FestivalSchedule(setIDs: setIDs)
    })

    await store.send(.destination(.presented(.schedulePick(.view(.setTapped("lime")))))) {
      $0.destination?.modify(\.schedulePick) { $0.selectedSetIDs = ["lime"] }
    }
    await store.send(.destination(.presented(.schedulePick(.view(.nextTapped))))) {
      $0.destination?.modify(\.schedulePick) { $0.isSaving = true }
    }
    await store.receive(\.destination.presented.schedulePick.async.save)
    await store.receive(\.destination.presented.schedulePick.inner.saveSucceeded) {
      $0.destination?.modify(\.schedulePick) { $0.isSaving = false }
    }
    await store.receive(\.destination.presented.schedulePick.delegate.saved) {
      $0.destination = nil
      $0.mySetIDs = ["lime"]
      $0.lastClientAt = now
    }
    await store.receive(\.delegate.scheduleSaved)

    #expect(saved.value.count == 1)
    #expect(saved.value.first?.festivalID == "fst")
    #expect(saved.value.first?.setIDs == ["lime"])
    #expect(saved.value.first?.clientAt == now)
  }

  @Test func failedSaveKeepsPickOpenWithMessageAndLeavesMySchedule() async {
    let attempts = LockIsolated(0)
    let store = makeStore(opened(readyState(mine: ["lime"])), save: { _, _, _ throws(FestivalScheduleError) in
      attempts.withValue { $0 += 1 }
      throw .unavailable
    })

    await store.send(.destination(.presented(.schedulePick(.view(.nextTapped))))) {
      $0.destination?.modify(\.schedulePick) { $0.isSaving = true }
    }
    await store.receive(\.destination.presented.schedulePick.async.save)
    await store.receive(\.destination.presented.schedulePick.inner.saveFailed) {
      $0.destination?.modify(\.schedulePick) {
        $0.isSaving = false
        $0.errorMessage = "내 일정을 저장하지 못했어요. 다시 시도해 주세요."
      }
    }

    #expect(attempts.value == 1)
    #expect(store.state.mySetIDs == ["lime"])
  }

  @Test func skippingClosesPickWithoutChangingMySchedule() async {
    let store = makeStore(opened(readyState(mine: ["lime"])), save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("건너뛰면 저장하지 않아야 한다")
      throw .unavailable
    })

    await store.send(.destination(.presented(.schedulePick(.view(.skipTapped)))))
    await store.receive(\.destination.presented.schedulePick.delegate.skipped) {
      $0.destination = nil
    }
  }

  @Test func accountChangeClosesOpenPick() async {
    let store = makeStore(opened(readyState()), save: { _, _, _ throws(FestivalScheduleError) in
      Issue.record("계정이 바뀌면 저장하지 않아야 한다")
      throw .unavailable
    }, fetch: { _ throws(FestivalScheduleError) in
      FestivalSchedule(setIDs: [])
    })

    await store.send(.view(.accountChanged)) {
      $0.destination = nil
      $0.accountGeneration = 1
      $0.loadRequestID = 2
      $0.scheduleSync = .loading
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.scheduleSync = .ready
    }
  }
}

private extension TimetableSchedulePickTests {
  func readyState(mine: Set<String> = []) -> TimetableFeature.State {
    var state = TimetableFeature.State.sample()
    state.festivalID = "fst"
    state.mySetIDs = mine
    state.scheduleSync = .ready
    return state
  }

  func opened(_ state: TimetableFeature.State) -> TimetableFeature.State {
    var state = state
    state.destination = .schedulePick(SchedulePickFeature.State(
      festivalID: "fst",
      days: state.days,
      selectedSetIDs: state.mySetIDs,
      previousClientAt: state.lastClientAt
    ))
    return state
  }

  func makeStore(
    _ state: TimetableFeature.State,
    save: @escaping @Sendable (String, [String], Date) async throws(FestivalScheduleError) -> FestivalSchedule,
    fetch: @escaping @Sendable (String) async throws(FestivalScheduleError) -> FestivalSchedule = { _ throws(FestivalScheduleError) in
      Issue.record("이 테스트는 서버 일정을 읽지 않아야 한다")
      throw .unavailable
    }
  ) -> TestStoreOf<TimetableFeature> {
    TestStore(initialState: state) {
      TimetableFeature()
    } withDependencies: {
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(
        mySchedule: fetch,
        saveMySchedule: save
      )
      $0.date.now = now
    }
  }
}
