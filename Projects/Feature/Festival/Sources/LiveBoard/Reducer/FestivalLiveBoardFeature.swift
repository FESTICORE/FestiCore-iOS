import ComposableArchitecture
import FestivalDomainInterface
import Foundation

/// 라이브 보드의 응답과 수신·오류 표시 상태를 맡는 자식 리듀서.
/// 축제 선택·계정 세대 확인과 조회 효과는 부모 `FestivalFeature`가 맡고, 확인된 결과만 view 입력 액션으로 받는다.
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

    public init() {}
  }

  public enum Action: ViewAction, Equatable {
    case view(View)
  }

  /// 부모가 축제·계정 세대를 확인한 뒤 보내는 입력.
  @CasePathable
  public enum View: Equatable {
    case snapshotLoaded(FestivalLiveBoardSnapshot)
    case unpublished
    case failed
    case retried
    case cleared
  }

  @Dependency(\.date) private var date

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
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
    case let .snapshotLoaded(snapshot):
      if state.snapshot?.serverAt != snapshot.serverAt || state.clockAnchorAt == nil {
        state.clockAnchorAt = date.now
      }
      state.snapshot = snapshot
      state.isUnavailable = false
      state.isUnpublished = false
      state.receivedAt = date.now
      return .none

    case .unpublished:
      state.snapshot = nil
      state.isUnavailable = false
      state.isUnpublished = true
      state.clockAnchorAt = nil
      state.receivedAt = nil
      return .none

    case .failed:
      state.isUnavailable = true
      return .none

    case .retried:
      state.isUnavailable = false
      return .none

    case .cleared:
      state = State()
      return .none
    }
  }
}
