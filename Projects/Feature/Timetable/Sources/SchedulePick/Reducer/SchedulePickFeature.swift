//
//  SchedulePickFeature.swift
//  Timetable
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import TimetableInterface

/// Figma S15-1 준비 안내 · 내 일정 고르기. 고른 공연을 서버 내 일정 전체로 저장한다.
@Reducer
public struct SchedulePickFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    public var days: [TimetableDay]
    public var selectedDayIndex = 0
    /// 고른 공연. 이미 저장된 내 일정으로 시작한다.
    public var selectedSetIDs: Set<String>
    public var isSaving = false
    public var errorMessage: String?

    public init(
      festivalID: String,
      days: [TimetableDay],
      selectedSetIDs: Set<String> = []
    ) {
      self.festivalID = festivalID
      self.days = days
      self.selectedSetIDs = selectedSetIDs
    }

    public var selectedDay: TimetableDay? {
      days.indices.contains(selectedDayIndex) ? days[selectedDayIndex] : nil
    }

    public var canSubmit: Bool {
      !isSaving && !selectedSetIDs.isEmpty
    }

    /// 같은 날 먼저 시작하는 고른 공연과 겹치면 그 공연 이름과 겹친 분을 돌려준다.
    public func overlap(of set: TimetableSet) -> (artist: String, minutes: Int)? {
      guard selectedSetIDs.contains(set.id), let day = selectedDay else { return nil }
      return day.sets
        .filter { $0.id != set.id && selectedSetIDs.contains($0.id) && $0.start < set.start }
        .compactMap { other -> (artist: String, minutes: Int)? in
          let minutes = min(other.end, set.end) - max(other.start, set.start)
          return minutes > 0 ? (other.artist, minutes) : nil
        }
        .max { $0.minutes < $1.minutes }
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case dayTapped(Int)
    case setTapped(String)
    case nextTapped
    case skipTapped
    case laterTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case save
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case saveSucceeded(FestivalSchedule)
    case saveFailed(FestivalScheduleError)
  }

  // MARK: - DelegateAction

  public typealias DelegateAction = SchedulePickDelegate

  @Dependency(\.festivalScheduleUseCase) private var scheduleUseCase
  @Dependency(\.date.now) private var now

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .delegate:
        return .none
      }
    }
  }
}

extension SchedulePickFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .dayTapped(let index):
      guard state.days.indices.contains(index) else { return .none }
      state.selectedDayIndex = index
      return .none

    case .setTapped(let setID):
      guard !state.isSaving else { return .none }
      if state.selectedSetIDs.remove(setID) == nil {
        guard state.selectedSetIDs.count < TimetableFeature.scheduleLimit else {
          state.errorMessage = "내 일정은 \(TimetableFeature.scheduleLimit)개까지 고를 수 있어요."
          return .none
        }
        state.selectedSetIDs.insert(setID)
      }
      state.errorMessage = nil
      return .none

    case .nextTapped:
      guard state.canSubmit else { return .none }
      state.isSaving = true
      state.errorMessage = nil
      return .send(.async(.save))

    case .skipTapped:
      guard !state.isSaving else { return .none }
      return .send(.delegate(.skipped))

    case .laterTapped:
      guard !state.isSaving else { return .none }
      return .send(.delegate(.later))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .save:
      let festivalID = state.festivalID
      let setIDs = state.selectedSetIDs.sorted()
      let clientAt = now
      return .run { [scheduleUseCase] send in
        do throws(FestivalScheduleError) {
          let schedule = try await scheduleUseCase.saveMySchedule(
            festivalID: festivalID,
            setIDs: setIDs,
            clientAt: clientAt
          )
          await send(.inner(.saveSucceeded(schedule)))
        } catch {
          await send(.inner(.saveFailed(error)))
        }
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .saveSucceeded(let schedule):
      state.isSaving = false
      state.selectedSetIDs = Set(schedule.setIDs)
      return .send(.delegate(.saved(festivalID: state.festivalID, setIDs: state.selectedSetIDs)))

    case .saveFailed(let error):
      state.isSaving = false
      switch error {
      case .stale(let schedule):
        // 다른 기기에서 더 늦게 바뀐 일정이 있으면 덮어쓰지 않고 서버 일정을 보여 준다.
        state.selectedSetIDs = Set(schedule.setIDs)
        state.errorMessage = "다른 기기에서 바뀐 일정을 불러왔어요. 확인하고 다시 눌러 주세요."
      case .unauthorized, .rejected, .unavailable:
        state.errorMessage = "내 일정을 저장하지 못했어요. 다시 시도해 주세요."
      }
      return .none
    }
  }
}
