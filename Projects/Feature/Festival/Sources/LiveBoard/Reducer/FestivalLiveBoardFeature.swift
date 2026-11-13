import ComposableArchitecture
import FestivalDomainInterface
import Foundation

/// 라이브 보드의 조회 효과와 응답·수신·오류 표시 상태를 맡는 자식 리듀서.
/// 시작 조건(포그라운드·화면 표시·축제 선택)은 부모 `FestivalFeature`가 판단해 시작·새로고침·중지 입력으로 보낸다.
@Reducer
public struct FestivalLiveBoardFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var snapshot: FestivalLiveBoardSnapshot?
    public var isUnavailable = false
    public var isUnpublished = false
    /// 현재 serverAt을 처음 받은 기기 시각. 304 응답에서도 서버 시각 보정 기준을 유지한다.
    public var clockAnchorAt: Date?
    /// 마지막으로 라이브 보드가 정상 확인된 기기 시각. 304 응답도 포함한다.
    public var receivedAt: Date?
    /// 부모가 자식 상태를 읽을 때마다 채우는 현재 선택 축제와 계정 세대.
    /// 응답이 지금 축제·계정의 것인지 확인하는 데만 쓰고, 부모 저장 상태에는 남기지 않는다.
    public var selectedFestivalID: String?
    public var accountGeneration = 0

    public init() {}
  }

  public enum Action: ViewAction, Equatable {
    case view(View)
    case inner(InnerAction)
  }

  // MARK: - ViewAction

  /// 부모가 시작 조건을 확인한 뒤 보내는 입력.
  @CasePathable
  public enum View: Equatable {
    case watchRequested(
      festivalID: String,
      generation: Int
    )
    case refreshRequested(
      festivalID: String,
      generation: Int
    )
    case stopped
    case retried
    case cleared
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction: Equatable {
    case liveBoardLoaded(String, generation: Int, FestivalLiveBoardSnapshot)
    case liveBoardFailed(String, generation: Int)
    case liveBoardUnpublished(String, generation: Int)
  }

  enum CancelID {
    case liveBoard
  }

  @Dependency(\.festivalLiveBoardUseCase) private var liveBoardUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case let .inner(innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )
      }
    }
  }
}

// MARK: - 액션 처리

extension FestivalLiveBoardFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .watchRequested(
      festivalID,
      generation
    ):
      return watchLiveBoard(
        festivalID: festivalID,
        generation: generation
      )

    case let .refreshRequested(
      festivalID,
      generation
    ):
      return refreshLiveBoard(
        festivalID: festivalID,
        generation: generation
      )

    case .stopped:
      return .cancel(id: CancelID.liveBoard)

    case .retried:
      state.isUnavailable = false
      return .none

    case .cleared:
      state = State()
      return .none
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .liveBoardLoaded(
      id,
      generation,
      snapshot
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      if state.snapshot?.serverAt != snapshot.serverAt || state.clockAnchorAt == nil {
        state.clockAnchorAt = date.now
      }
      state.snapshot = snapshot
      state.isUnavailable = false
      state.isUnpublished = false
      state.receivedAt = date.now
      return .none

    case let .liveBoardUnpublished(
      id,
      generation
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.snapshot = nil
      state.isUnavailable = false
      state.isUnpublished = true
      state.clockAnchorAt = nil
      state.receivedAt = nil
      return .none

    case let .liveBoardFailed(
      id,
      generation
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.isUnavailable = true
      return .none
    }
  }

  private func watchLiveBoard(
    festivalID id: String,
    generation: Int
  ) -> Effect<Action> {
    return .run { send in
      while !Task.isCancelled {
        var interval: TimeInterval = 35
        do {
          let snapshot = try await liveBoardUseCase.liveBoard(for: id)
          await send(.inner(.liveBoardLoaded(
            id,
            generation: generation,
            snapshot
          )))
        } catch FestivalLiveBoardError.festivalNotFound {
          await send(.inner(.liveBoardUnpublished(
            id,
            generation: generation
          )))
        } catch FestivalLiveBoardError.rateLimited(let retryAfter) {
          // 조회 제한은 장애가 아니다. 보이던 보드를 그대로 두고 허용 시각 뒤에 다시 불러온다.
          interval = max(
            interval,
            retryAfter
          )
        } catch {
          await send(.inner(.liveBoardFailed(
            id,
            generation: generation
          )))
        }
        try await clock.sleep(for: .seconds(interval))
      }
    }
    .cancellable(
      id: CancelID.liveBoard,
      cancelInFlight: true
    )
  }

  private func refreshLiveBoard(
    festivalID id: String,
    generation: Int
  ) -> Effect<Action> {
    return .run { send in
      do {
        await send(.inner(.liveBoardLoaded(
          id,
          generation: generation,
          try await liveBoardUseCase.liveBoard(for: id)
        )))
      } catch FestivalLiveBoardError.festivalNotFound {
        await send(.inner(.liveBoardUnpublished(
          id,
          generation: generation
        )))
      } catch {
        await send(.inner(.liveBoardFailed(
          id,
          generation: generation
        )))
      }
    }
  }
}
