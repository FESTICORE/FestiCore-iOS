//
//  MainTabCoordinator+Sync.swift
//  FestiCore
//
//  Created by FestiCore on 11/11/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import Foundation

// MARK: - 라이브 보드와 탭 동기화

extension MainTabCoordinator {
  /// 축제 화면이 바뀌면 지금 보이는 타임테이블·깃발 탭에 반영한다.
  func syncSelectedTab(state: inout State) -> Effect<Action> {
    switch state.selectedTab {
    case .timetable:
      return syncTimetable(
        state: &state,
        appearing: false
      )
    case .flag:
      return syncFlag(state: &state)
    case .live, .my:
      return .none
    }
  }

  func syncFlag(state: inout State) -> Effect<Action> {
    let board = flagBoard(state)
    let selectedID = board?.selectedFestivalID
    let pack = board?.displayDocument
    // 깃발 카드의 구역 칩은 선택 축제 팩의 구역 이름을 쓴다. 다른 축제의 팩이면 비운다.
    let zones = pack?.id == selectedID ? pack?.zones ?? [] : []
    let zoneNames = Dictionary(
      zones.map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first }
    )
    if state.flagState.directory.zoneNames != zoneNames {
      state.flagState.directory.zoneNames = zoneNames
    }
    let festivalEffect: Effect<Action> = selectedID == state.flagState.festivalID
      ? .none
      : .send(.flagDirectory(.view(.festivalChanged(selectedID))))
    // 열린 깃발 상세에 팩·내 일정·계정 변경을 알린다.
    guard state.flagCoordinatorState.isDetailOpen else { return festivalEffect }
    return .merge(
      festivalEffect,
      .send(.flagCoordinator(.navigation(.updateDetailContext(flagDetailContext(state)))))
    )
  }

  /// 깃발 탭이 따르는 축제 보드. 기수 보드·알림함은 라이브 보드 위에 덮이는 화면이라 그 아래 축제를 기준으로 삼는다.
  func flagBoard(_ state: State) -> FestivalFeature.State? {
    return state.festivalState.routes.last { $0.screen.festivalBoard != nil }?.screen.festivalBoard
  }

  func flagDetailContext(_ state: State) -> FestivalFlagDetailContext {
    return FestivalFlagDetailContext(
      board: flagBoard(state),
      snapshot: state.flagState.snapshot
    )
  }

  /// 라이브 보드에서 고른 축제의 팩을 타임테이블에 옮긴다.
  /// 고른 축제가 없으면 이전 축제의 시간표가 남지 않게 비운다.
  func syncTimetable(
    state: inout State,
    appearing: Bool
  ) -> Effect<Action> {
    let home = state.festivalState.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard
    let festivalID = home?.selectedFestivalID
    let pack = home?.displayDocument.flatMap { $0.id == festivalID ? $0 : nil }
    let sameFestival = festivalID == state.timetableState.festivalID
    let previousDays = sameFestival ? state.timetableState.days : []
    let days = pack.map {
      FestivalPackTimetableMapper.days(
        from: $0,
        previousDays: previousDays,
        imageURL: { home?.imageURL(for: $0) }
      )
    } ?? []
    let daysChanged = state.timetableState.days != days
    let selectedDayID = state.timetableState.selectedDay?.id
    state.timetableState.days = days
    state.timetableState.selectedDayIndex = days.firstIndex { $0.id == selectedDayID } ?? 0
    state.timetableState.lineup = pack.map {
      FestivalPackTimetableMapper.lineup(
        from: $0,
        imageURL: { home?.imageURL(for: $0) }
      )
    } ?? []
    state.timetableState.source = FestivalPackTimetableMapper.source(pack?.source)
    if festivalID == nil {
      state.timetableState.contentStatus = .noFestival
    } else if let pack {
      state.timetableState.contentStatus = pack.performances.isEmpty ? .unpublished : .published
    } else if home?.onlineDetailLoading == true
      || (home?.connection == .loading && home?.onlineDetailFailed != true && home?.packWatchFailed != true) {
      state.timetableState.contentStatus = .loading
    } else {
      state.timetableState.contentStatus = .failed
    }
    state.timetableState.offlineMessage = nil
    if home?.connection == .offline, pack != nil {
      if let id = festivalID, let checkedAt = home?.cachedPacks[id]?.checkedAt {
        let minutes = max(
          0,
          Int(now.timeIntervalSince(checkedAt) / 60)
        )
        state.timetableState.offlineMessage = minutes == 0
          ? "오프라인 · 방금 확인한 정보"
          : "오프라인 · \(minutes)분 전 정보"
      } else {
        state.timetableState.offlineMessage = "오프라인 · 저장된 정보"
      }
    }
    if let list = state.timetableCoordinatorState.setList {
      state.timetableCoordinatorState.setList = sameFestival
        ? TimetableSetListFeature.State(
          mode: list.mode,
          days: days,
          query: list.query
        )
        : nil
    }
    if !sameFestival {
      return .send(.timetable(.view(.festivalChanged(festivalID))))
    }
    guard daysChanged || appearing else { return .none }
    return .run { send in
      if daysChanged {
        await send(.timetable(.view(.packUpdated)))
      }
      if appearing {
        await send(.timetable(.view(.timetableAppeared)))
      }
    }
  }
}
