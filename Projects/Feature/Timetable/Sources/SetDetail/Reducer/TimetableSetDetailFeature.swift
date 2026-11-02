//
//  TimetableSetDetailFeature.swift
//  Timetable
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import Foundation

/// 공연 상세 시트. 내 일정 저장과 겹침 계산은 타임테이블 화면이 맡고, 시트는 받은 내용을 보여 준다.
@Reducer
public struct TimetableSetDetailFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable, Identifiable {
    public let setID: String
    public var content: Content
    /// 내 일정에 넣은 직후 시트 위에 보이는 "내 일정에 추가됐어요" 토스트
    public var isScheduleToastVisible = false

    public init(
      setID: String,
      content: Content
    ) {
      self.setID = setID
      self.content = content
    }

    /// 다른 공연을 열면 새 시트로 보고 이전 시트의 토스트 효과를 멈춘다.
    public var id: String {
      setID
    }

    /// 열린 동안 공연 시작·종료 시각이 지나면 상태가 바뀌므로 화면이 현재 시각을 넘긴다.
    public func detail(now: Date) -> TimetableSetDetail {
      var detail = content.detail
      detail.status = .init(interval: content.interval, now: now)
      return detail
    }
  }

  /// 타임테이블 화면이 계산해 넘기는 시트 내용
  public struct Content: Equatable, Sendable {
    public var detail: TimetableSetDetail
    /// 공연의 실제 시작·종료 시각
    public var interval: DateInterval
    public var source: String
    /// 서버 일정을 읽는 중이다. 이 동안에는 내 일정을 바꾸지 않는다.
    public var isScheduleLoading: Bool
    /// 60개를 넘겨 추가하지 못했다.
    public var isScheduleLimitReached: Bool

    public init(
      detail: TimetableSetDetail,
      interval: DateInterval,
      source: String,
      isScheduleLoading: Bool,
      isScheduleLimitReached: Bool
    ) {
      self.detail = detail
      self.interval = interval
      self.source = source
      self.isScheduleLoading = isScheduleLoading
      self.isScheduleLimitReached = isScheduleLimitReached
    }
  }

  public enum Action: ViewAction {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View {
    case scheduleToggled
  }

  // MARK: - AsyncAction

  @CasePathable
  public enum AsyncAction {
    /// 내 일정에 넣었다. 토스트를 2초 보여 준다. 다시 넣으면 처음부터 센다.
    case showScheduleToast
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction: Equatable {
    /// 타임테이블 화면의 일정·시간표가 바뀌어 시트 내용을 새로 받는다.
    case contentChanged(Content)
    case scheduleToastExpired
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    /// 내 일정 넣기·빼기를 눌렀다. 저장은 타임테이블 화면이 한다.
    case scheduleToggled
  }

  enum CancelID {
    case toast
  }

  @Dependency(\.continuousClock) var clock

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case let .async(asyncAction):
        return handleAsyncAction(
          state: &state,
          action: asyncAction
        )

      case let .inner(innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )

      case .delegate:
        return .none
      }
    }
  }
}

extension TimetableSetDetailFeature {
  private func handleViewAction(
    state _: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .scheduleToggled:
      return .send(.delegate(.scheduleToggled))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .showScheduleToast:
      state.isScheduleToastVisible = true
      return .run { [clock] send in
        try await clock.sleep(for: .seconds(2))
        await send(.inner(.scheduleToastExpired))
      }
      .cancellable(id: CancelID.toast, cancelInFlight: true)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .contentChanged(content):
      state.content = content
      // 공연을 빼거나 서버 결과가 방금 넣은 공연을 되돌렸으면 토스트를 바로 숨긴다.
      guard state.isScheduleToastVisible, !content.detail.isScheduled else { return .none }
      state.isScheduleToastVisible = false
      return .cancel(id: CancelID.toast)

    case .scheduleToastExpired:
      state.isScheduleToastVisible = false
      return .none
    }
  }
}
