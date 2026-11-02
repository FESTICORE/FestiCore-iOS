//
//  TimetableFeature.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import TimetableDomainInterface
import TimetableInterface

@Reducer
public struct TimetableFeature {
  public init() {}

  /// 서버 일정은 최대 60개까지 저장된다.
  public static let scheduleLimit = 60

  public enum ScheduleSync: Equatable, Sendable {
    /// 축제가 없어 이 기기에만 표시한다.
    case idle
    /// 서버 일정을 읽는 중이다. 이 동안에는 일정을 바꾸지 않는다.
    case loading
    /// 서버와 맞춰져 바꿀 때마다 저장한다.
    case ready
    /// 로그인 전이거나 연결이 없어 이 기기에만 표시한다. 다음 진입 때 다시 읽는다.
    case localOnly
  }

  public struct ScheduleSave: Equatable, Sendable {
    let setIDs: [String]
    let clientAt: Date
    let generation: Int
  }

  enum CancelID {
    case load
    case save
  }

  @ObservableState
  public struct State: Equatable {
    public var days: [TimetableDay]
    /// 시간표 공개 전 라인업. 비어 있지 않으면 시간표 대신 보여 준다.
    public var lineup: [TimetableLineupDay] = []
    public var selectedDayIndex = 0
    public var mySetIDs: Set<String> = []
    public var showsMineOnly = false
    /// 핀치로 확정한 시간축 배율. 날짜를 바꾸거나 화면을 다시 그려도 유지한다.
    public var zoom: Double = 1
    /// 현재 시각(분). 오늘이 아니면 nil이다.
    public var nowMinute: Int?
    /// 오프라인일 때 보여 줄 안내. 온라인이면 nil이다.
    public var offlineMessage: String?
    public var source: String
    public var festivalID: String?
    /// 상세 시트로 연 공연
    @Presents public var setDetail: TimetableSetDetailFeature.State?
    public var scheduleSync: ScheduleSync = .idle
    /// 60개를 넘겨 추가하지 못했다.
    public var isScheduleLimitReached = false
    var loadRequestID = 0
    var accountGeneration = 0
    var isSaving = false
    var needsSave = false
    var lastClientAt: Date?
    /// 결과를 알 수 없는 저장. 목록이 그대로면 같은 요청으로 다시 보낸다.
    var uncertainSave: ScheduleSave?

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

    var allSetIDs: Set<String> {
      Set(days.flatMap { $0.sets.map(\.id) })
    }

    /// 선택한 날 공연이 낀 내 일정 겹침. 자정을 넘겨 다음 날 공연과 겹치는 구간도 포함한다.
    public var overlaps: [TimetableOverlap] {
      guard let day = selectedDay else { return [] }
      let mine = myIntervals
      return mine.indices.flatMap { index in
        mine[(index + 1)...].compactMap { other in
          let current = mine[index]
          guard current.dayID == day.id || other.dayID == day.id,
                let shared = current.interval.intersection(with: other.interval),
                shared.duration > 0 else { return nil }
          return TimetableOverlap(
            start: Int(shared.start.timeIntervalSince(day.date) / 60),
            end: Int(shared.end.timeIntervalSince(day.date) / 60)
          )
        }
      }
    }

    func isOverlapping(_ set: TimetableSet) -> Bool {
      guard mySetIDs.contains(set.id), let day = selectedDay else { return false }
      return !overlaps(of: set, in: day).isEmpty
    }

    /// 상세 시트 내용. 시각이 흐르면 상태가 바뀌므로 현재 시각을 받는다.
    func setDetailContent(
      id: String,
      now: Date
    ) -> TimetableSetDetailFeature.Content? {
      guard let day = days.first(where: { $0.sets.contains { $0.id == id } }),
            let set = day.sets.first(where: { $0.id == id }) else { return nil }
      let interval = day.interval(of: set)
      let detail = TimetableSetDetail(
        artist: set.artist,
        stage: day.stages.first { $0.id == set.stageID }?.name ?? "무대 미정",
        time: set.timeRangeWithDuration,
        status: .init(interval: interval, now: now),
        isScheduled: mySetIDs.contains(id),
        overlap: overlaps(of: set, in: day).first,
        previousTime: set.previousTime,
        change: set.startChange
      )
      return TimetableSetDetailFeature.Content(
        detail: detail,
        interval: interval,
        source: source,
        isScheduleLoading: scheduleSync == .loading,
        isScheduleLimitReached: isScheduleLimitReached
      )
    }

    private var myIntervals: [(set: TimetableSet, dayID: String, interval: DateInterval)] {
      days
        .flatMap { day in
          day.sets.filter { mySetIDs.contains($0.id) }.map { (set: $0, dayID: day.id, interval: day.interval(of: $0)) }
        }
        .sorted { $0.interval.start < $1.interval.start }
    }

    /// 시간이 겹치는 다른 내 일정 공연. 시작 시각순이다.
    private func overlaps(of set: TimetableSet, in day: TimetableDay) -> [TimetableSetOverlap] {
      let interval = day.interval(of: set)
      return myIntervals.compactMap { mine in
        guard mine.set.id != set.id,
              let shared = mine.interval.intersection(with: interval),
              shared.duration > 0 else { return nil }
        let stages = days.first { $0.id == mine.dayID }?.stages ?? []
        return TimetableSetOverlap(
          artist: mine.set.artist,
          stage: stages.first { $0.id == mine.set.stageID }?.name ?? "무대 미정",
          time: mine.set.timeRange,
          minutes: Int((shared.duration / 60).rounded())
        )
      }
    }
  }

  public enum Action: ViewAction {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case scope(ScopeAction)
    case delegate(TimetableDelegate)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View {
    case daySelected(Int)
    case mineOnlyToggled
    case setTapped(String)
    case zoomChanged(Double)
    case changeBannerTapped
    case searchTapped
    case notifyTapped
  }

  // MARK: - AsyncAction

  @CasePathable
  public enum AsyncAction {
    /// 서버 일정을 읽는다.
    case fetchSchedule(festivalID: String, requestID: Int)
    /// 내 일정 목록을 서버에 저장한다.
    case replaceSchedule(festivalID: String, ScheduleSave)
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction {
    /// 선택한 축제가 바뀌었다. 팩이 없으면 nil이다.
    case festivalChanged(String?)
    /// 인증 계정이 바뀌거나 세션을 잃었다.
    case accountChanged
    /// 같은 축제의 팩이 갱신돼 공연 목록이 바뀌었다.
    case packUpdated
    /// 같은 축제로 타임테이블 탭에 다시 들어왔다.
    case timetableAppeared
    case scheduleLoaded(festivalID: String, requestID: Int, Result<FestivalSchedule, FestivalScheduleError>)
    case scheduleSaved(festivalID: String, ScheduleSave, Result<FestivalSchedule, FestivalScheduleError>)
  }

  // MARK: - ScopeAction

  @CasePathable
  public enum ScopeAction {
    case setDetail(PresentationAction<TimetableSetDetailFeature.Action>)
  }

  @Dependency(\.festivalScheduleUseCase) var scheduleUseCase
  @Dependency(\.date.now) var now

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      let effect: Effect<Action>
      switch action {
      case let .view(viewAction):
        effect = handleViewAction(
          state: &state,
          action: viewAction
        )

      case let .async(asyncAction):
        effect = handleAsyncAction(
          state: &state,
          action: asyncAction
        )

      case let .inner(innerAction):
        effect = handleInnerAction(
          state: &state,
          action: innerAction
        )

      case let .scope(scopeAction):
        effect = handleScopeAction(
          state: &state,
          action: scopeAction
        )

      case .delegate:
        effect = .none
      }
      // 일정·시간표가 바뀌면 열린 상세 시트에 새 내용을 다른 효과보다 먼저 보낸다.
      return .merge(refreshSetDetail(state: state), effect)
    }
    .ifLet(\.$setDetail, action: \.scope.setDetail) {
      TimetableSetDetailFeature()
    }
  }
}

extension TimetableFeature {
  private func handleViewAction(
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
      state.setDetail = state.setDetailContent(id: id, now: now).map {
        TimetableSetDetailFeature.State(setID: id, content: $0)
      }
      return .none

    case let .zoomChanged(zoom):
      state.zoom = zoom
      return .none

    case .changeBannerTapped:
      return .send(.delegate(.showChanges))

    case .searchTapped:
      return .send(.delegate(.search))

    case .notifyTapped:
      return .send(.delegate(.requestNotification))
    }
  }

  private func handleAsyncAction(
    state _: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case let .fetchSchedule(festivalID, requestID):
      return .run { [scheduleUseCase] send in
        let result: Result<FestivalSchedule, FestivalScheduleError>
        do throws(FestivalScheduleError) {
          result = try .success(await scheduleUseCase.mySchedule(festivalID: festivalID))
        } catch {
          result = .failure(error)
        }
        await send(.inner(.scheduleLoaded(festivalID: festivalID, requestID: requestID, result)))
      }
      .cancellable(id: CancelID.load, cancelInFlight: true)

    case let .replaceSchedule(festivalID, save):
      return .run { [scheduleUseCase] send in
        let result: Result<FestivalSchedule, FestivalScheduleError>
        do throws(FestivalScheduleError) {
          result = try .success(await scheduleUseCase.saveMySchedule(
            festivalID: festivalID,
            setIDs: save.setIDs,
            clientAt: save.clientAt
          ))
        } catch {
          result = .failure(error)
        }
        await send(.inner(.scheduleSaved(festivalID: festivalID, save, result)))
      }
      .cancellable(id: CancelID.save)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .festivalChanged(festivalID):
      return changeFestival(state: &state, to: festivalID)

    case .accountChanged:
      return changeAccount(state: &state)

    case .packUpdated:
      return trimSchedule(state: &state)

    case .timetableAppeared:
      guard state.festivalID != nil, !state.isSaving else { return .none }
      return state.uncertainSave == nil ? loadSchedule(state: &state) : saveSchedule(state: &state)

    case let .scheduleLoaded(festivalID, requestID, result):
      return applyLoadedSchedule(state: &state, festivalID: festivalID, requestID: requestID, result: result)

    case let .scheduleSaved(festivalID, save, result):
      return applySavedSchedule(state: &state, festivalID: festivalID, save: save, result: result)
    }
  }

  private func handleScopeAction(
    state: inout State,
    action: ScopeAction
  ) -> Effect<Action> {
    switch action {
    case .setDetail(.presented(.delegate(.scheduleToggled))):
      return toggleSchedule(state: &state)

    case .setDetail(.dismiss):
      state.isScheduleLimitReached = false
      return .none

    case .setDetail:
      return .none
    }
  }
}
