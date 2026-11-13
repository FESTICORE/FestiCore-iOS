//
//  FestivalFlagDetailFeature.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import FestivalInterface
import Foundation

/// Figma S05 깃발 상세. 프로필·지금 상태·오늘 계획을 보이고 팔로우·잠금화면 표시·신고를 처리한다.
@Reducer
public struct FestivalFlagDetailFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 화면 본문 단계.
    public enum Content: Equatable {
      case loading
      case loaded(FestivalFlagDetail)
      case failed(Failure)
    }

    /// 첫 조회 실패 종류.
    public enum Failure: Equatable {
      case notFound
      case unavailable
    }

    /// 화면 아래 짧은 안내.
    public enum Toast: Equatable {
      case followed(name: String)
      case followLimit
      case followFailed
      case reported
      case alreadyReported
      case reportFailed
      case pinFailed
    }

    /// 팔로우 응답으로 바뀐 값. 다음 조회 결과가 오면 비운다.
    struct FollowOverride: Equatable {
      let isFollowing: Bool
      let followerCount: Int
    }

    /// 잠금화면 대표 깃발 토글. 응답 전에는 누른 값을 먼저 보이고, 실패하면 되돌린다.
    struct PinState: Equatable {
      var override: Bool?
      var isPending = false
    }

    public let flagID: String
    public var context: FestivalFlagDetailContext
    public var content: Content = .loading
    /// 마지막으로 상세를 받은 기기 시각. 오프라인 안내에 쓴다.
    public var lastLoadedAt: Date?
    /// 받은 상세가 있는데 다시 불러오지 못했다. 마지막 상세를 그대로 보인다.
    public var isOffline = false
    public var isFollowPending = false
    public var isReportPending = false
    public var toast: Toast?
    public var now: Date
    @Presents public var destination: Destination.State?
    var followOverride: FollowOverride?
    var pin = PinState()
    /// 조회마다 올린다. 화면을 닫았거나 다시 연 뒤 늦게 온 응답을 버린다.
    var loadGeneration = 0

    public init(
      flagID: String,
      context: FestivalFlagDetailContext,
      now: Date = .now
    ) {
      self.flagID = flagID
      self.context = context
      self.now = now
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case destination(PresentationAction<Destination.Action>)
    case delegate(DelegateAction)
  }

  // MARK: - View

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case onDisappear
    case retryTapped
    case followTapped
    case backTapped
    case lockScreenToggled(Bool)
    case reportTapped
    /// 부모가 축제 팩·내 일정·계정이 바뀌었을 때 보내는 새 표시 입력.
    case contextChanged(FestivalFlagDetailContext)
  }

  // MARK: - Async

  @CasePathable
  public enum AsyncAction: Equatable {
    case load(generation: Int)
    case follow(Bool)
    case setPinned(Bool)
    case report(FestivalFlagReportReason)
    case startClock
    case showToast(State.Toast)
  }

  // MARK: - Inner

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(
      generation: Int,
      detail: FestivalFlagDetail,
      at: Date
    )
    case loadFailed(
      generation: Int,
      error: FestivalFlagDetailError
    )
    case followFinished(Result<FestivalFlagFollowResult, FestivalFlagFollowError>)
    case pinFinished(
      requested: Bool,
      Result<String?, FestivalFlagPinError>
    )
    case reported
    case reportFailed(FestivalFlagReportError)
    case clockTicked(Date)
    case toastExpired
  }

  // MARK: - Destination

  @Reducer(
    state: .equatable,
    action: .equatable
  )
  public enum Destination {
    case report(FestivalFlagReportFeature)
  }

  // MARK: - Delegate

  public typealias DelegateAction = FestivalFlagDetailDelegate

  enum CancelID: Hashable {
    case load
    case clock
    case follow
    case pin
    case report
    case toast
  }

  @Dependency(\.festivalFlagDetailUseCase) private var detailUseCase
  @Dependency(\.festivalFlagUseCase) private var flagUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock
  @Dependency(\.analyticsUseCase) private var analyticsUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case .async(let asyncAction):
        return handleAsyncAction(
          state: &state,
          action: asyncAction
        )

      case .inner(let innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )

      case .destination(let destinationAction):
        return handleDestinationAction(
          state: &state,
          action: destinationAction
        )

      case .delegate:
        return .none
      }
    }
    .ifLet(
      \.$destination,
      action: \.destination
    )
  }
}

// MARK: - View 처리

extension FestivalFlagDetailFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      state.loadGeneration += 1
      state.now = date.now
      // 받은 상세가 있으면 그대로 두고 새로 불러온다.
      if case .failed = state.content { state.content = .loading }
      return .merge(
        .send(.async(.load(generation: state.loadGeneration))),
        .send(.async(.startClock))
      )

    case .onDisappear:
      // 닫은 화면에 늦은 조회·팔로우·신고·대표 결과나 로그인 요청이 오지 않게 모두 멈춘다.
      state.loadGeneration += 1
      state.isFollowPending = false
      state.isReportPending = false
      state.pin = State.PinState()
      return .merge(
        .cancel(id: CancelID.load),
        .cancel(id: CancelID.clock),
        .cancel(id: CancelID.follow),
        .cancel(id: CancelID.pin),
        .cancel(id: CancelID.report)
      )

    case .retryTapped:
      state.loadGeneration += 1
      if case .failed = state.content { state.content = .loading }
      return .send(.async(.load(generation: state.loadGeneration)))

    case .followTapped:
      guard state.detail != nil, !state.isFollowPending, !state.isOffline else { return .none }
      guard state.context.hasSession else { return .send(.delegate(.loginRequested)) }
      state.isFollowPending = true
      return .send(.async(.follow(!state.isFollowing)))

    case .backTapped:
      return .send(.delegate(.backRequested))

    case let .lockScreenToggled(isOn):
      guard state.showsLockScreenToggle,
            !state.pin.isPending,
            !state.isOffline,
            isOn != state.isPinned else { return .none }
      // 토글은 누른 값을 먼저 보이고 응답으로 확정한다.
      state.pin = State.PinState(
        override: isOn,
        isPending: true
      )
      return .send(.async(.setPinned(isOn)))

    case .reportTapped:
      guard state.detail != nil, !state.isReportPending else { return .none }
      guard state.context.hasSession else { return .send(.delegate(.reportLoginRequested)) }
      state.destination = .report(FestivalFlagReportFeature.State())
      return .none

    case let .contextChanged(context):
      let isAccountChanged = context.hasSession != state.context.hasSession
        || context.accountID != state.context.accountID
      state.context = context
      guard isAccountChanged else { return .none }
      return resetForAccountChange(state: &state)
    }
  }

  /// 다른 계정의 팔로우·대표 깃발 값이 남지 않게 비우고 새 계정으로 다시 불러온다.
  private func resetForAccountChange(state: inout State) -> Effect<Action> {
    state.followOverride = nil
    state.isFollowPending = false
    state.isReportPending = false
    state.pin = State.PinState()
    state.destination = nil
    state.content = .loading
    state.isOffline = false
    state.loadGeneration += 1
    return .merge(
      .cancel(id: CancelID.follow),
      .cancel(id: CancelID.pin),
      .cancel(id: CancelID.report),
      .send(.async(.load(generation: state.loadGeneration)))
    )
  }
}

// MARK: - Async 처리

extension FestivalFlagDetailFeature {
  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case let .load(generation):
      let flagID = state.flagID
      return .run { [detailUseCase, date] send in
        do {
          let detail = try await detailUseCase.detail(flagID: flagID)
          await send(.inner(.loaded(
            generation: generation,
            detail: detail,
            at: date.now
          )))
        } catch let error as FestivalFlagDetailError {
          await send(.inner(.loadFailed(
            generation: generation,
            error: error
          )))
        } catch {
          await send(.inner(.loadFailed(
            generation: generation,
            error: .unavailable
          )))
        }
      }
      .cancellable(
        id: CancelID.load,
        cancelInFlight: true
      )

    case let .follow(following):
      let flagID = state.flagID
      return .run { [flagUseCase] send in
        do {
          let result = try await flagUseCase.setFollowing(
            following,
            flagID: flagID
          )
          await send(.inner(.followFinished(.success(result))))
        } catch let error as FestivalFlagFollowError {
          await send(.inner(.followFinished(.failure(error))))
        } catch {
          await send(.inner(.followFinished(.failure(.unavailable))))
        }
      }
      .cancellable(
        id: CancelID.follow,
        cancelInFlight: true
      )

    case let .setPinned(isOn):
      let pinnedFlagID = isOn ? state.flagID : nil
      return .run { [detailUseCase] send in
        do {
          let saved = try await detailUseCase.setPinnedFlag(pinnedFlagID)
          await send(.inner(.pinFinished(
            requested: isOn,
            .success(saved)
          )))
        } catch let error as FestivalFlagPinError {
          await send(.inner(.pinFinished(
            requested: isOn,
            .failure(error)
          )))
        } catch {
          await send(.inner(.pinFinished(
            requested: isOn,
            .failure(.unavailable)
          )))
        }
      }
      .cancellable(
        id: CancelID.pin,
        cancelInFlight: true
      )

    case let .report(reason):
      let flagID = state.flagID
      return .run { [detailUseCase] send in
        do {
          try await detailUseCase.report(
            flagID: flagID,
            reason: reason
          )
          await send(.inner(.reported))
        } catch let error as FestivalFlagReportError {
          await send(.inner(.reportFailed(error)))
        } catch {
          await send(.inner(.reportFailed(.unavailable)))
        }
      }
      .cancellable(
        id: CancelID.report,
        cancelInFlight: true
      )

    case .startClock:
      return .run { [clock, date] send in
        for await _ in clock.timer(interval: .seconds(60)) {
          await send(.inner(.clockTicked(date.now)))
        }
      }
      .cancellable(
        id: CancelID.clock,
        cancelInFlight: true
      )

    case let .showToast(toast):
      state.toast = toast
      return .run { [clock] send in
        try await clock.sleep(for: .seconds(2))
        await send(.inner(.toastExpired))
      }
      .cancellable(
        id: CancelID.toast,
        cancelInFlight: true
      )
    }
  }
}

// MARK: - Inner 처리

extension FestivalFlagDetailFeature {
  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(
      generation,
      detail,
      at
    ):
      guard generation == state.loadGeneration else { return .none }
      state.content = .loaded(detail)
      state.lastLoadedAt = at
      state.now = at
      state.isOffline = false
      state.followOverride = nil
      // 대표 깃발을 바꾸는 중이 아니면 서버 값을 따른다.
      if !state.pin.isPending { state.pin.override = nil }
      return .none

    case let .loadFailed(
      generation,
      error
    ):
      guard generation == state.loadGeneration else { return .none }
      if error == .notFound {
        state.content = .failed(.notFound)
        state.isOffline = false
      } else if state.detail != nil {
        // 받은 상세는 남기고 오프라인으로 알린다.
        state.isOffline = true
      } else {
        state.content = .failed(.unavailable)
      }
      return .none

    case let .followFinished(result):
      // 화면을 떠나며 취소한 요청의 늦은 응답은 버린다.
      guard state.isFollowPending else { return .none }
      state.isFollowPending = false
      return handleFollowResult(
        state: &state,
        result: result
      )

    case let .pinFinished(
      requested,
      result
    ):
      guard state.pin.isPending else { return .none }
      return handlePinResult(
        state: &state,
        requested: requested,
        result: result
      )

    case .reported:
      guard state.isReportPending else { return .none }
      state.isReportPending = false
      return .send(.async(.showToast(.reported)))

    case let .reportFailed(error):
      guard state.isReportPending else { return .none }
      state.isReportPending = false
      switch error {
      case .loginRequired:
        return .send(.delegate(.reportLoginRequested))
      case .termsRequired:
        return .send(.delegate(.termsAcceptanceRequested))
      case .alreadyReported:
        return .send(.async(.showToast(.alreadyReported)))
      case .notFound, .invalidRequest, .invalidResponse, .unavailable:
        return .send(.async(.showToast(.reportFailed)))
      }

    case let .clockTicked(now):
      state.now = now
      return .none

    case .toastExpired:
      state.toast = nil
      return .none
    }
  }

  private func handleFollowResult(
    state: inout State,
    result: Result<FestivalFlagFollowResult, FestivalFlagFollowError>
  ) -> Effect<Action> {
    switch result {
    case let .success(response):
      state.followOverride = State.FollowOverride(
        isFollowing: response.isFollowing,
        followerCount: response.followerCount
      )
      analyticsUseCase.track(.flagFollow(FlagFollowData(
        flagID: response.flagID,
        isFollowing: response.isFollowing
      )))
      // 첫 팔로우는 서버가 대표 깃발로 정하고, 해제하면 다른 깃발로 옮긴다. 다시 불러와 서버 값을 받는다.
      state.pin = State.PinState()
      state.loadGeneration += 1
      var effects: [Effect<Action>] = [
        .send(.delegate(.followChanged(
          flagID: response.flagID,
          isFollowing: response.isFollowing,
          followerCount: response.followerCount
        ))),
        .send(.async(.load(generation: state.loadGeneration))),
      ]
      if response.isFollowing, let name = state.detail?.name {
        effects.append(.send(.async(.showToast(.followed(name: name)))))
      }
      return .merge(effects)
    case .failure(.loginRequired):
      return .send(.delegate(.loginRequested))
    case .failure(.termsRequired):
      return .send(.delegate(.termsAcceptanceRequested))
    case .failure(.limitReached):
      return .send(.async(.showToast(.followLimit)))
    case .failure:
      return .send(.async(.showToast(.followFailed)))
    }
  }

  private func handlePinResult(
    state: inout State,
    requested: Bool,
    result: Result<String?, FestivalFlagPinError>
  ) -> Effect<Action> {
    switch result {
    case let .success(pinnedFlagID):
      state.pin = State.PinState(override: pinnedFlagID == state.flagID)
      return .none
    case let .failure(error):
      // 요청 전 값으로 되돌린다. 토글은 다른 값일 때만 요청하므로 이전 값은 요청의 반대다.
      state.pin = State.PinState(override: !requested)
      switch error {
      case .loginRequired:
        return .send(.delegate(.reportLoginRequested))
      case .termsRequired:
        return .send(.delegate(.termsAcceptanceRequested))
      case .notFollowing, .invalidRequest, .invalidResponse, .unavailable:
        return .send(.async(.showToast(.pinFailed)))
      }
    }
  }
}

// MARK: - Destination 처리

extension FestivalFlagDetailFeature {
  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case let .presented(.report(.delegate(.submitted(reason)))):
      state.destination = nil
      state.isReportPending = true
      return .send(.async(.report(reason)))

    case .presented, .dismiss:
      return .none
    }
  }
}

// MARK: - 화면 파생 값

extension FestivalFlagDetailFeature.State {
  /// 이 시간 이상 지난 위치는 지금과 다를 수 있다고 알린다.
  static let staleInterval: TimeInterval = 30 * 60

  public var detail: FestivalFlagDetail? {
    guard case let .loaded(detail) = content else { return nil }
    return detail
  }

  public var isFollowing: Bool {
    return followOverride?.isFollowing ?? detail?.isFollowing ?? false
  }

  public var followerCount: Int {
    return followOverride?.followerCount ?? detail?.followerCount ?? 0
  }

  /// 히어로 태그. 서버 태그 코드를 디렉토리와 같은 이름으로 바꾼다.
  public var tagTitles: [String] {
    return (detail?.tags ?? []).map { tag in
      return FestivalFlagDirectory.Tag(rawValue: tag)?.title ?? tag
    }
  }

  /// 잠금화면 대표 깃발 여부. 누른 값 → 상세 응답 → 라이브 보드가 알려 준 대표 깃발 순으로 따른다.
  public var isPinned: Bool {
    return pin.override ?? detail?.isPinned ?? (context.pinnedFlagID == flagID)
  }

  /// "잠금화면에 표시"는 로그인해 팔로우 중인 깃발에만 보인다.
  public var showsLockScreenToggle: Bool {
    return detail != nil && context.hasSession && isFollowing
  }

  /// 공유 시트로 보내는 깃발 링크(`festicore://flag/<id>`). 앱의 링크 처리가 깃발 상세로 연다.
  public var shareURL: URL {
    var components = URLComponents()
    components.scheme = "festicore"
    components.host = "flag"
    components.path = "/\(flagID)"
    return components.url ?? URL(fileURLWithPath: "/")
  }

  /// 상단 오프라인 안내. 받은 상세가 있는데 다시 불러오지 못했을 때만 보인다.
  public var offlineText: String? {
    guard isOffline else { return nil }
    return FestivalFlagDirectory.offlineText(
      receivedAt: lastLoadedAt,
      now: now
    )
  }

  var nowCard: FestivalFlagDetailNow? {
    guard let detail else { return nil }
    if detail.status == .ended { return .ended }
    let zoneID = detail.zoneID ?? detail.homeZoneID
    let zone = zoneID.flatMap { context.zoneNames[$0] } ?? "위치를 아직 알리지 않았어요"
    let isStale = now.timeIntervalSince(detail.statusUpdatedAt) >= Self.staleInterval
    return .located(
      zone: zone,
      activity: activityText(detail),
      source: sourceText(
        detail,
        isStale: isStale
      ),
      // Figma S05 F: 쉬는 중은 기본 카드로 보이고, 오래된 정보·오프라인만 흐리게 보인다.
      isMuted: isStale || isOffline
    )
  }

  var planRows: [FestivalFlagDetailPlanRow] {
    guard let detail else { return [] }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "HH:mm"
    // 기수가 정한 순서를 그대로 두고, 받은 팩에 없는 공연은 건너뛴다.
    return detail.planSetIDs.compactMap { id in
      guard let performance = context.performances[id] else { return nil }
      return FestivalFlagDetailPlanRow(
        id: id,
        time: formatter.string(from: performance.startsAt),
        artist: performance.artist,
        stage: performance.stageName,
        timing: timing(
          performance,
          isEnded: detail.status == .ended
        ),
        isMine: context.mySetIDs.contains(id)
      )
    }
  }

  private func activityText(_ detail: FestivalFlagDetail) -> String {
    if detail.status == .resting { return "쉬는 중" }
    // 시작 전 깃발은 활동 값이 남아 있어도 예정으로 보인다.
    if detail.status == .scheduled { return "예정" }
    switch detail.activity {
    case .slam: return "슬램"
    case .sing: return "떼창"
    case .train: return "기차놀이"
    case .calm: return "차분"
    case .resting: return "쉬는 중"
    case nil: return "활동 중"
    }
  }

  private func sourceText(
    _ detail: FestivalFlagDetail,
    isStale: Bool
  ) -> String {
    if isOffline { return "마지막으로 받은 정보예요" }
    let relative = FestivalLiveBoardPresentation.relativeTime(
      detail.statusUpdatedAt,
      now: now
    ) ?? "방금"
    if isStale { return "\(relative) 정보예요 · 지금은 다를 수 있어요" }
    return relative == "방금" ? "기수가 방금 알렸어요" : "기수가 \(relative)에 알렸어요"
  }

  private func timing(
    _ performance: FestivalFlagDetailContext.Performance,
    isEnded: Bool
  ) -> FestivalFlagDetailPlanRow.Timing {
    if isEnded || performance.endsAt <= now { return .past }
    return performance.startsAt <= now ? .now : .upcoming
  }
}
