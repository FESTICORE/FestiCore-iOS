//
//  TimetableFeature.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import Foundation

@Reducer
public struct TimetableFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var days: [TimetableDay]
    /// 시간표 공개 전 라인업. 비어 있지 않으면 시간표 대신 보여 준다.
    public var lineup: [TimetableLineupDay] = []
    public var selectedDayIndex = 0
    public var mySetIDs: Set<String> = []
    public var showsMineOnly = false
    /// 현재 시각(분). 오늘이 아니면 nil이다.
    public var nowMinute: Int?
    /// 오프라인일 때 보여 줄 안내. 온라인이면 nil이다.
    public var offlineMessage: String?
    public var source: String

    public init(
      days: [TimetableDay],
      source: String
    ) {
      self.days = days
      self.source = source
    }

    public var isPublished: Bool {
      lineup.isEmpty
    }

    public var selectedDay: TimetableDay? {
      days.indices.contains(selectedDayIndex) ? days[selectedDayIndex] : nil
    }

    public var mySetCount: Int {
      selectedDay?.sets.count { mySetIDs.contains($0.id) } ?? 0
    }

    /// 선택한 날의 내 일정끼리 겹치는 구간
    public var overlaps: [TimetableOverlap] {
      let mine = (selectedDay?.sets ?? [])
        .filter { mySetIDs.contains($0.id) }
        .sorted { $0.start < $1.start }
      return mine.indices.flatMap { index in
        mine[(index + 1)...].compactMap { other in
          guard mine[index].overlaps(other) else { return nil }
          return TimetableOverlap(
            start: max(mine[index].start, other.start),
            end: min(mine[index].end, other.end)
          )
        }
      }
    }

    func isOverlapping(_ set: TimetableSet) -> Bool {
      guard mySetIDs.contains(set.id) else { return false }
      return (selectedDay?.sets ?? []).contains { other in
        other.id != set.id && mySetIDs.contains(other.id) && set.overlaps(other)
      }
    }
  }

  public enum Action: ViewAction {
    case view(View)
    case delegate(Delegate)
  }

  @CasePathable
  public enum View {
    case daySelected(Int)
    case mineOnlyToggled
    case setTapped(String)
    case changeBannerTapped
    case searchTapped
    case notifyTapped
  }

  @CasePathable
  public enum Delegate {
    case showChanges
    case search
    case requestNotification
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case .delegate:
        return .none
      }
    }
  }
}

private extension TimetableFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .daySelected(index):
      guard state.days.indices.contains(index) else { return .none }
      state.selectedDayIndex = index
      return .none

    case .mineOnlyToggled:
      state.showsMineOnly.toggle()
      return .none

    case let .setTapped(id):
      if state.mySetIDs.remove(id) == nil {
        state.mySetIDs.insert(id)
      }
      return .none

    case .changeBannerTapped:
      return .send(.delegate(.showChanges))

    case .searchTapped:
      return .send(.delegate(.search))

    case .notifyTapped:
      return .send(.delegate(.requestNotification))
    }
  }
}
