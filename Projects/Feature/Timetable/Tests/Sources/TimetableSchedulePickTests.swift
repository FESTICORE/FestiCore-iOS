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
      selectedSetIDs: state.mySetIDs
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
