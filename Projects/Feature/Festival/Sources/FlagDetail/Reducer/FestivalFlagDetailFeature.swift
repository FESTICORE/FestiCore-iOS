//
//  FestivalFlagDetailFeature.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import FestivalInterface
import Foundation

/// Figma S05 깃발 상세. 프로필·지금 상태·오늘 계획을 보이고 팔로우를 바꾼다.
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

    /// 팔로우 응답으로 바뀐 값. 다음 조회 결과가 오면 비운다.
    struct FollowOverride: Equatable {
      let isFollowing: Bool
      let followerCount: Int
    }

    public let flagID: String
    public var context: FestivalFlagDetailContext
    public var content: Content = .loading
    /// 마지막으로 상세를 받은 기기 시각. 오프라인 안내에 쓴다.
    public var lastLoadedAt: Date?
    /// 받은 상세가 있는데 다시 불러오지 못했다. 마지막 상세를 그대로 보인다.
    public var isOffline = false
    public var isFollowPending = false
    public var toast: String?
    public var now: Date
    var followOverride: FollowOverride?
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
  }

  // MARK: - Async

  @CasePathable
  public enum AsyncAction: Equatable {
    case load(generation: Int)
    case follow(Bool)
    case startClock
    case showToast(String)
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
    case clockTicked(Date)
    case toastExpired
  }

  // MARK: - Delegate

  public typealias DelegateAction = FestivalFlagDetailDelegate

  enum CancelID: Hashable {
    case load
    case clock
    case follow
    case toast
  }

  @Dependency(\.festivalFlagDetailUseCase) private var detailUseCase
  @Dependency(\.festivalFlagUseCase) private var flagUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

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

      case .delegate:
        return .none
      }
    }
  }
}

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
      state.loadGeneration += 1
      return .merge(
        .cancel(id: CancelID.load),
        .cancel(id: CancelID.clock)
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
    }
  }

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

    case let .showToast(message):
      state.toast = message
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
      state.isFollowPending = false
      switch result {
      case let .success(response):
        state.followOverride = State.FollowOverride(
          isFollowing: response.isFollowing,
          followerCount: response.followerCount
        )
        return .none
      case .failure(.loginRequired):
        return .send(.delegate(.loginRequested))
      case .failure(.termsRequired):
        return .send(.delegate(.termsAcceptanceRequested))
      case .failure(.limitReached):
        return .send(.async(.showToast("팔로우는 100개까지 할 수 있어요")))
      case .failure:
        return .send(.async(.showToast("팔로우를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요")))
      }

    case let .clockTicked(now):
      state.now = now
      return .none

    case .toastExpired:
      state.toast = nil
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
      isMuted: detail.status == .resting || isStale || isOffline
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
    switch detail.activity {
    case .slam: return "슬램"
    case .sing: return "떼창"
    case .train: return "기차놀이"
    case .calm: return "차분"
    case .resting: return "쉬는 중"
    case nil: return detail.status == .scheduled ? "예정" : "활동 중"
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
