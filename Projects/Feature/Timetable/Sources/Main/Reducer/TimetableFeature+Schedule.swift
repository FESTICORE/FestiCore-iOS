//
//  TimetableFeature+Schedule.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation

/// 내 일정 서버 동기화.
/// 저장은 한 번에 하나만 보내고, 그동안 바뀐 목록은 끝난 뒤 마지막 목록으로 한 번 더 저장한다.
/// 충돌하면 다른 기기의 변경을 지키기 위해 서버 일정을 따른다.
extension TimetableFeature {
  func changeFestival(
    state: inout State,
    to festivalID: String?
  ) -> Effect<Action> {
    guard festivalID != state.festivalID else { return .none }
    state.festivalID = festivalID
    state.mySetIDs = []
    state.selectedSetID = nil
    state.scheduleSync = .idle
    state.isScheduleLimitReached = false
    state.isSaving = false
    state.needsSave = false
    state.lastClientAt = nil
    state.uncertainSave = nil
    return .concatenate(
      .cancel(id: CancelID.load),
      .cancel(id: CancelID.save),
      loadSchedule(state: &state)
    )
  }

  func toggleSchedule(state: inout State) -> Effect<Action> {
    guard let id = state.selectedSetID, state.scheduleSync != .loading else { return .none }
    if state.mySetIDs.remove(id) != nil {
      state.isScheduleLimitReached = false
    } else {
      guard state.setDetail(now: now)?.status != .ended else { return .none }
      guard state.mySetIDs.count < Self.scheduleLimit else {
        state.isScheduleLimitReached = true
        return .none
      }
      state.mySetIDs.insert(id)
    }
    guard state.scheduleSync == .ready else { return .none }
    return saveSchedule(state: &state)
  }

  /// 팩에서 사라진 공연을 내 일정에서 뺀다. 없는 공연 ID는 서버가 거부한다.
  func trimSchedule(state: inout State) -> Effect<Action> {
    let validIDs = state.allSetIDs
    if let selectedID = state.selectedSetID, !validIDs.contains(selectedID) {
      state.selectedSetID = nil
    }
    let trimmed = state.mySetIDs.intersection(validIDs)
    guard trimmed != state.mySetIDs else { return .none }
    state.mySetIDs = trimmed
    guard state.scheduleSync == .ready else { return .none }
    return saveSchedule(state: &state)
  }

  func loadSchedule(state: inout State) -> Effect<Action> {
    guard let festivalID = state.festivalID, state.scheduleSync != .loading else { return .none }
    state.scheduleSync = .loading
    state.loadRequestID += 1
    let requestID = state.loadRequestID
    return .run { [scheduleService] send in
      let result: Result<FestivalSchedule, FestivalScheduleError>
      do throws(FestivalScheduleError) {
        result = try .success(await scheduleService.fetch(festivalID: festivalID))
      } catch {
        result = .failure(error)
      }
      await send(.scheduleLoaded(festivalID: festivalID, requestID: requestID, result))
    }
    .cancellable(id: CancelID.load, cancelInFlight: true)
  }

  func saveSchedule(state: inout State) -> Effect<Action> {
    guard !state.isSaving else {
      state.needsSave = true
      return .none
    }
    if let uncertain = state.uncertainSave {
      state.uncertainSave = nil
      // 결과를 모르는 요청과 목록이 같으면 같은 요청을 다시 보내 서버가 중복으로 처리하게 한다.
      // 다르면 그사이 다른 기기가 저장했을 수 있어 서버 일정을 먼저 읽는다.
      guard Set(uncertain.setIDs) == state.mySetIDs else { return loadSchedule(state: &state) }
      return startSave(uncertain, state: &state)
    }
    // 서버는 같은 시각의 다른 목록을 충돌로 보므로 이전 요청보다 1ms 이상 늦춘다.
    let clientAt = max(now, (state.lastClientAt ?? .distantPast).addingTimeInterval(0.001))
    state.lastClientAt = clientAt
    return startSave(ScheduleSave(setIDs: state.mySetIDs.sorted(), clientAt: clientAt), state: &state)
  }

  func applyLoadedSchedule(
    state: inout State,
    festivalID: String,
    requestID: Int,
    result: Result<FestivalSchedule, FestivalScheduleError>
  ) -> Effect<Action> {
    guard festivalID == state.festivalID,
          requestID == state.loadRequestID,
          state.scheduleSync == .loading else { return .none }
    switch result {
    case let .success(schedule):
      state.mySetIDs = Set(schedule.setIDs).intersection(state.allSetIDs)
      state.scheduleSync = .ready
    case .failure:
      state.scheduleSync = .localOnly
    }
    return .none
  }

  func applySavedSchedule(
    state: inout State,
    festivalID: String,
    save: ScheduleSave,
    result: Result<FestivalSchedule, FestivalScheduleError>
  ) -> Effect<Action> {
    guard festivalID == state.festivalID else { return .none }
    state.isSaving = false
    let needsSave = state.needsSave
    state.needsSave = false
    switch result {
    case .success:
      return needsSave ? saveSchedule(state: &state) : .none
    case let .failure(.stale(server)):
      state.mySetIDs = Set(server.setIDs).intersection(state.allSetIDs)
      return .none
    case .failure(.unauthorized):
      state.scheduleSync = .localOnly
      return .none
    case .failure(.rejected):
      return loadSchedule(state: &state)
    case .failure(.unavailable):
      state.uncertainSave = save
      return .none
    }
  }
}

private extension TimetableFeature {
  func startSave(
    _ save: ScheduleSave,
    state: inout State
  ) -> Effect<Action> {
    guard let festivalID = state.festivalID else { return .none }
    state.isSaving = true
    return .run { [scheduleService] send in
      let result: Result<FestivalSchedule, FestivalScheduleError>
      do throws(FestivalScheduleError) {
        result = try .success(await scheduleService.replace(
          festivalID: festivalID,
          setIDs: save.setIDs,
          clientAt: save.clientAt
        ))
      } catch {
        result = .failure(error)
      }
      await send(.scheduleSaved(festivalID: festivalID, save, result))
    }
    .cancellable(id: CancelID.save)
  }
}
