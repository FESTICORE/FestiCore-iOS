//
//  BearerBoardFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import BearerInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation

/// Figma S09 A~J 기수 보드. 누르면 바로 화면에 반영하고, 보내지 못한 변경은 순서대로 다시 보낸다.
@Reducer
public struct BearerBoardFeature {
  public init() {}

  static let checkDuration: Duration = .seconds(1)

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    public let flagID: String
    /// 로그인한 사용자. 다른 공동 기수가 바꿨는지 가린다.
    public let viewerUserID: String?

    public var board: BearerBoard?
    public var festival: BearerFestival?
    public var isLoading = false
    public var loadFailed = false
    /// 화면에 보이는 지금 상태. 보내기 전 변경까지 반영한다.
    public var current: Current?
    /// 쉬는 중에서 다시 시작할 때 쓰는 마지막 활동
    public var lastActivity: BearerActivity?

    /// 아직 서버에 반영하지 못한 변경. 대기열(BearerStatusOutbox)의 목록을 비춘다.
    public var pending: [BearerStatusRequest] = []
    public var isOffline = false
    /// 로그인·서버 오류로 자동 전송이 멈췄다. 다시 보내기를 눌러야 이어진다.
    public var isSendPaused = false
    /// 서버 상태를 마지막으로 확인한 시각
    public var lastSyncedAt: Date?
    public var errorMessage: String?

    public var sheet: Sheet?
    public var check: Check?
    var checkSequence = 0

    @Presents public var destination: Destination.State?

    public init(festivalID: String, flagID: String, viewerUserID: String?) {
      self.festivalID = festivalID
      self.flagID = flagID
      self.viewerUserID = viewerUserID
    }
  }

  public struct Current: Equatable, Sendable {
    public var lifecycle: BearerFlagLifecycle
    public var zoneID: String?
    public var activity: BearerActivity?
    public var updatedAt: Date
    public var updatedBy: BearerCoBearer?

    init(_ status: BearerFlagStatus) {
      lifecycle = status.lifecycle
      zoneID = status.zoneID
      activity = status.activity
      updatedAt = status.updatedAt
      updatedBy = status.updatedBy
    }
  }

  /// 어떤 흐름에서 시트를 열었는지
  public enum Sheet: Equatable, Sendable {
    case move
    case changeActivity
    case startZone
    case startActivity(zoneID: String)
    case restartZone
    case restartActivity(zoneID: String)
  }

  /// Figma S09 D 누른 직후 1초 확인
  public struct Check: Equatable, Sendable {
    public let id: Int
    public let title: String
    public let message: String
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case destination(PresentationAction<Destination.Action>)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case onDisappear
    case retryTapped
    case closeTapped
    case retrySendTapped
    case zoneTapped
    case activityTapped
    case restTapped
    case resumeTapped
    case endTapped
    case raiseTapped
    case restartTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
    case observeOutbox
    case enqueue(BearerStatusRequest)
    case retrySend
    case expireCheck(Int)
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(BearerBoard, BearerFestival?)
    case loadFailed(BearerError)
    case pendingLoaded([BearerStatusRequest])
    case outbox(BearerOutboxEvent)
    case checkExpired(Int)
  }

  // MARK: - Destination

  @Reducer(state: .equatable, action: .equatable)
  public enum Destination {
    case zonePicker(BearerZonePickerFeature)
    case activityPicker(BearerActivityPickerFeature)
    case alert(FCConfirmAlert)
    case closeConfirm(FCConfirmAlert)
  }

  // MARK: - DelegateAction

  public typealias DelegateAction = BearerBoardDelegate

  enum CancelID {
    case load
    case outbox
    case check
  }

  @Dependency(\.bearerUseCase) private var bearerUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .destination(let destinationAction):
        return handleDestinationAction(state: &state, action: destinationAction)

      case .delegate(let delegateAction):
        return handleDelegateAction(state: &state, action: delegateAction)
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension BearerBoardFeature.State {
  public var zones: [BearerZone] { festival?.zones ?? [] }

  public func zoneName(for zoneID: String?) -> String? {
    festival?.zoneName(for: zoneID)
  }

  /// 오늘 재시작을 이미 썼는지. 보내기 전 재시작도 포함한다.
  public var restartUsedToday: Bool {
    (board?.restartUsedToday ?? false) || pending.contains {
      if case .restart = $0.change { return true }
      return false
    }
  }

  /// 다른 공동 기수가 마지막으로 바꿨으면 그 기수
  public var changedByOtherBearer: BearerCoBearer? {
    guard let updatedBy = current?.updatedBy, updatedBy.userID != viewerUserID else { return nil }
    return updatedBy
  }
}

extension BearerBoardFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      // 대기열을 먼저 구독하고 보내지 못한 변경을 받은 뒤 상태를 읽는다(pendingLoaded).
      return .send(.async(.observeOutbox))

    case .onDisappear:
      // 화면 라우트를 지워도 자식 효과는 남으므로 구독을 직접 끝낸다. 대기열 전송은 계속된다.
      return .merge(
        .cancel(id: CancelID.outbox),
        .cancel(id: CancelID.load),
        .cancel(id: CancelID.check)
      )

    case .retrySendTapped:
      state.isSendPaused = false
      state.errorMessage = nil
      return .send(.async(.retrySend))

    case .retryTapped:
      return .send(.async(.load))

    case .closeTapped:
      // 닫아도 대기열은 남아 이어서 보내지만, 아직 못 보낸 변경이 있으면 한 번 알린다.
      guard state.pending.isEmpty else {
        state.destination = .closeConfirm(.bearerClosePending(count: state.pending.count))
        return .none
      }
      return .send(.delegate(.closeRequested))

    case .zoneTapped:
      guard let current = state.current, current.lifecycle == .active || current.lifecycle == .resting else {
        return .none
      }
      return presentZonePicker(&state, for: .move, selected: current.zoneID)

    case .activityTapped:
      guard let current = state.current, current.lifecycle == .active || current.lifecycle == .resting else {
        return .none
      }
      state.sheet = .changeActivity
      state.destination = .activityPicker(.init(selected: current.activity ?? state.lastActivity))
      return .none

    case .restTapped:
      guard state.current?.lifecycle == .active else { return .none }
      return enqueue(&state, .rest)

    case .resumeTapped:
      guard state.current?.lifecycle == .resting else { return .none }
      if let activity = state.lastActivity {
        return enqueue(&state, .activity(activity))
      }
      state.sheet = .changeActivity
      state.destination = .activityPicker(.init(selected: nil))
      return .none

    case .endTapped:
      guard let lifecycle = state.current?.lifecycle, lifecycle != .ended else { return .none }
      state.destination = .alert(.bearerEndToday())
      return .none

    case .raiseTapped:
      guard state.current?.lifecycle == .scheduled else { return .none }
      return presentZonePicker(&state, for: .startZone, selected: state.board?.profile.homeZoneID)

    case .restartTapped:
      guard state.current?.lifecycle == .ended, !state.restartUsedToday else { return .none }
      return presentZonePicker(&state, for: .restartZone, selected: state.board?.profile.homeZoneID)
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .load:
      state.isLoading = true
      state.loadFailed = false
      let flagID = state.flagID
      let festivalID = state.festivalID
      return .run { send in
        async let festival = try? bearerUseCase.fetchFestival(festivalID: festivalID)
        do {
          let board = try await bearerUseCase.fetchBoard(flagID: flagID)
          await send(.inner(.loaded(board, await festival)))
        } catch let error as BearerError {
          _ = await festival
          await send(.inner(.loadFailed(error)))
        } catch {
          _ = await festival
          await send(.inner(.loadFailed(.unavailable)))
        }
      }
      .cancellable(id: CancelID.load, cancelInFlight: true)

    case .observeOutbox:
      let flagID = state.flagID
      return .run { send in
        let events = await bearerUseCase.statusEvents(flagID: flagID)
        await send(.inner(.pendingLoaded(await bearerUseCase.pendingStatus(flagID: flagID))))
        await bearerUseCase.retryPendingStatus()
        for await event in events {
          await send(.inner(.outbox(event)))
        }
      }
      .cancellable(id: CancelID.outbox, cancelInFlight: true)

    case .enqueue(let request):
      guard let ownerUserID = state.viewerUserID else { return .none }
      let flagID = state.flagID
      return .run { _ in
        await bearerUseCase.enqueueStatus(flagID: flagID, ownerUserID: ownerUserID, request: request)
      }

    case .retrySend:
      return .run { _ in
        await bearerUseCase.retryPendingStatus()
      }

    case .expireCheck(let id):
      return .run { send in
        try await clock.sleep(for: Self.checkDuration)
        await send(.inner(.checkExpired(id)))
      }
      .cancellable(id: CancelID.check, cancelInFlight: true)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(board, festival):
      state.isLoading = false
      state.board = board
      if let festival { state.festival = festival }
      state.lastSyncedAt = date.now
      state.isOffline = false
      // 보내지 못한 변경이 있으면 서버 상태 위에 그 변경을 다시 얹어 보인다.
      adopt(board.status, into: &state)
      applyPending(&state)
      return .none

    case .loadFailed(let error):
      state.isLoading = false
      if state.board == nil {
        state.loadFailed = true
        state.errorMessage = Self.loadMessage(for: error)
      } else {
        state.isOffline = error == .offline
      }
      return .none

    case .pendingLoaded(let pending):
      state.pending = pending
      applyPending(&state)
      return state.board == nil ? .send(.async(.load)) : .none

    case .outbox(let event):
      return handleOutboxEvent(state: &state, event: event)

    case .checkExpired(let id):
      if state.check?.id == id { state.check = nil }
      return .none
    }
  }

  private func handleOutboxEvent(
    state: inout State,
    event: BearerOutboxEvent
  ) -> Effect<Action> {
    switch event {
    case .pending(let pending):
      state.pending = pending
      return .none

    case .sent(_, let status):
      state.isOffline = false
      state.isSendPaused = false
      state.errorMessage = nil
      state.lastSyncedAt = date.now
      if state.pending.isEmpty { adopt(status, into: &state) }
      return .none

    case .offline:
      state.isOffline = true
      return .none

    case .needsLogin:
      state.isSendPaused = true
      state.errorMessage = "로그인이 풀렸어요. 다시 로그인하면 이어서 보내요"
      return .none

    case .gaveUp:
      state.isSendPaused = true
      state.errorMessage = "서버에 보내지 못했어요. 잠시 뒤 다시 보내기를 눌러 주세요"
      return .none

    case .rejected(let error):
      state.errorMessage = Self.rejectMessage(for: error)
      return .send(.async(.load))
    }
  }

  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.zonePicker(.delegate(.picked(let zoneID)))):
      let sheet = state.sheet
      state.destination = nil
      switch sheet {
      case .move?:
        state.sheet = nil
        guard zoneID != state.current?.zoneID else { return .none }
        return enqueue(&state, .move(zoneID: zoneID))
      case .startZone?:
        state.sheet = .startActivity(zoneID: zoneID)
        state.destination = .activityPicker(.init(selected: state.lastActivity))
        return .none
      case .restartZone?:
        state.sheet = .restartActivity(zoneID: zoneID)
        state.destination = .activityPicker(.init(selected: state.lastActivity))
        return .none
      default:
        state.sheet = nil
        return .none
      }

    case .presented(.activityPicker(.delegate(.picked(let activity)))):
      let sheet = state.sheet
      state.destination = nil
      state.sheet = nil
      switch sheet {
      case .changeActivity?:
        guard state.current?.lifecycle == .resting || activity != state.current?.activity else { return .none }
        return enqueue(&state, .activity(activity))
      case .startActivity(let zoneID)?:
        return enqueue(&state, .start(zoneID: zoneID, activity: activity))
      case .restartActivity(let zoneID)?:
        return enqueue(&state, .restart(zoneID: zoneID, activity: activity))
      default:
        return .none
      }

    case .presented(.alert(.confirmTapped)):
      state.destination = nil
      return enqueue(&state, .end)

    case .presented(.alert(.cancelTapped)), .presented(.closeConfirm(.cancelTapped)):
      state.destination = nil
      return .none

    case .presented(.closeConfirm(.confirmTapped)):
      state.destination = nil
      return .send(.delegate(.closeRequested))

    case .dismiss:
      state.sheet = nil
      return .none

    case .presented:
      return .none
    }
  }

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    switch action {
    case .closeRequested:
      return .none
    }
  }
}

extension BearerBoardFeature {
  private func presentZonePicker(_ state: inout State, for sheet: Sheet, selected: String?) -> Effect<Action> {
    state.sheet = sheet
    state.destination = .zonePicker(.init(zones: state.zones, selectedZoneID: selected))
    return .none
  }

  /// 화면에 먼저 반영하고 대기열에 넣는다. 보내는 중이 아니면 바로 보낸다.
  private func enqueue(_ state: inout State, _ change: BearerStatusChange) -> Effect<Action> {
    // 누른 사용자를 모르면 다른 계정으로 보낼 수 있어 받지 않는다.
    guard state.viewerUserID != nil else {
      state.errorMessage = "로그인한 뒤에 바꿀 수 있어요"
      return .none
    }
    let request = bearerUseCase.makeStatusRequest(change)
    state.pending.append(request)
    state.errorMessage = nil
    if var current = state.current {
      apply(change, to: &current, at: request.clientAt)
      state.current = current
    }
    if case .activity(let activity) = change { state.lastActivity = activity }
    if case .start(_, let activity) = change { state.lastActivity = activity }
    if case .restart(_, let activity) = change { state.lastActivity = activity }
    state.checkSequence += 1
    state.check = Check(
      id: state.checkSequence,
      title: checkTitle(for: change, state: state),
      message: state.isOffline ? "연결되면 팔로워에게 알려요" : "팔로워에게 알렸어요"
    )
    return .merge(
      .send(.async(.expireCheck(state.checkSequence))),
      .send(.async(.enqueue(request)))
    )
  }

  private func apply(_ change: BearerStatusChange, to current: inout Current, at date: Date) {
    switch change {
    case let .start(zoneID, activity), let .restart(zoneID, activity):
      current.lifecycle = .active
      current.zoneID = zoneID
      current.activity = activity
    case .move(let zoneID):
      current.zoneID = zoneID
    case .activity(let activity):
      current.lifecycle = .active
      current.activity = activity
    case .rest:
      current.lifecycle = .resting
      current.activity = nil
    case .end:
      current.lifecycle = .ended
      current.zoneID = nil
      current.activity = nil
    }
    current.updatedAt = date
    current.updatedBy = nil
  }

  private func applyPending(_ state: inout State) {
    guard var current = state.current else { return }
    for request in state.pending {
      apply(request.change, to: &current, at: request.clientAt)
    }
    state.current = current
  }

  private func adopt(_ status: BearerFlagStatus, into state: inout State) {
    state.current = Current(status)
    if let activity = status.activity { state.lastActivity = activity }
  }

  private func checkTitle(for change: BearerStatusChange, state: State) -> String {
    switch change {
    case .start: return "깃발을 올렸어요"
    case .restart: return "깃발을 다시 올렸어요"
    case .move(let zoneID): return "\((state.zoneName(for: zoneID) ?? "새 존").withEuro) 바뀌었어요"
    case .activity(let activity): return "\(activity.title.withEuro) 바뀌었어요"
    case .rest: return "쉬는 중으로 바뀌었어요"
    case .end: return "오늘 깃발을 내렸어요"
    }
  }

  static func loadMessage(for error: BearerError) -> String {
    switch error {
    case .offline: return "인터넷에 연결되지 않아 기수 보드를 열지 못했어요"
    case .notBearer: return "이 깃발의 기수가 아니에요"
    case .notFound: return "깃발을 찾을 수 없어요"
    case .notAuthenticated: return "로그인한 뒤에 열어 주세요"
    default: return "기수 보드를 불러오지 못했어요"
    }
  }

  static func rejectMessage(for error: BearerError) -> String {
    switch error {
    case .stale: return "다른 기기에서 먼저 바뀌어 최신 상태로 돌렸어요"
    case .transitionRejected: return "지금 상태에서는 바꿀 수 없어 최신 상태로 돌렸어요"
    case .zoneNotFound: return "존을 찾을 수 없어 최신 상태로 돌렸어요"
    case .notBearer: return "이 깃발의 기수가 아니에요"
    case .termsRequired: return "새 약관에 동의한 뒤에 바꿀 수 있어요"
    case .notAuthenticated: return "로그인한 뒤에 바꿀 수 있어요"
    default: return "바꾸지 못해 최신 상태로 돌렸어요"
    }
  }
}
