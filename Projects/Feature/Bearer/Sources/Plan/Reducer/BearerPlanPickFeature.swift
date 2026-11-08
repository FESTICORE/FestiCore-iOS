//
//  BearerPlanPickFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/8/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreUtility
import Foundation

/// 깃발 프로필(S10)의 '오늘 계획' 고르기. 받아 둔 팩의 공연을 날짜별로 보여 주고 고른 셋을 프로필에 돌려준다.
/// 화면 구성은 내 일정 고르기(S15-1)와 같다. 서버 저장은 프로필 저장(`PATCH flags/:id`의 plan)이 맡는다.
@Reducer
public struct BearerPlanPickFeature {
  public init() {}

  /// 서버 plan 최대 개수
  static let planLimit = 30

  @ObservableState
  public struct State: Equatable {
    public let days: [Day]
    public var selectedDayIndex = 0
    public var selectedSetIDs: Set<String>
    public var limitMessage: String?

    /// - Parameter plan: 이미 고른 오늘 계획. 첫 화면은 그 공연이 있는 날로 연다.
    public init(
      sets: [BearerSet],
      plan: [String]
    ) {
      let days = Self.days(from: sets)
      self.days = days
      let selected = Set(plan)
      selectedSetIDs = selected
      selectedDayIndex = days.firstIndex { day in
        return day.sets.contains { selected.contains($0.id) }
      } ?? 0
    }

    public var selectedDay: Day? {
      return days.indices.contains(selectedDayIndex) ? days[selectedDayIndex] : nil
    }

    /// 고른 공연을 시작 순으로 돌려준다. 팩에 없는 예전 셋은 그대로 뒤에 둔다.
    public var orderedPlan: [String] {
      let known = days.flatMap(\.sets).map(\.id).filter { selectedSetIDs.contains($0) }
      let unknown = selectedSetIDs.subtracting(known).sorted()
      return known + unknown
    }

    /// 공연을 서울 기준 시작 날짜로 묶는다.
    static func days(from sets: [BearerSet]) -> [Day] {
      let calendar = AppDateFormat.calendar
      let grouped = Dictionary(grouping: sets) { calendar.startOfDay(for: $0.startsAt) }
      return grouped.keys.sorted().map { date in
        return Day(
          date: date,
          sets: (grouped[date] ?? []).sorted { $0.startsAt < $1.startsAt }
        )
      }
    }
  }

  public struct Day: Equatable, Identifiable, Sendable {
    public let date: Date
    public let sets: [BearerSet]

    public var id: Date { return date }
    public var title: String { return date.formatted(.festivalDay) }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(Delegate)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case dayTapped(Int)
    case setTapped(String)
    case doneTapped
    case backTapped
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum Delegate: Equatable {
    /// 고른 공연(시작 순). 부모가 프로필에 넣는다.
    case picked([String])
    case closeRequested
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
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

extension BearerPlanPickFeature {
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
      if state.selectedSetIDs.contains(setID) {
        state.selectedSetIDs.remove(setID)
        state.limitMessage = nil
        return .none
      }
      guard state.selectedSetIDs.count < Self.planLimit else {
        state.limitMessage = "오늘 계획은 \(Self.planLimit)개까지 고를 수 있어요."
        return .none
      }
      state.selectedSetIDs.insert(setID)
      return .none

    case .doneTapped:
      return .send(.delegate(.picked(state.orderedPlan)))

    case .backTapped:
      return .send(.delegate(.closeRequested))
    }
  }
}
