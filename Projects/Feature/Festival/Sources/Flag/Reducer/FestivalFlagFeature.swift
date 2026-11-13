import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestivalDomainInterface

@Reducer
public struct FestivalFlagFeature {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService
  @Dependency(\.continuousClock) private var clock
  @Dependency(\.analyticsUseCase) private var analyticsUseCase

  public init() {}

  @ObservableState
  public struct State: Equatable {
    public enum ViewState: Equatable {
      case idle
      case loading
      case loaded
      case failed
      case deviceNotRegistered
      case invalidFestivalID
      case invalidResponse
    }

    public var directory = FestivalFlagDirectory.State()
    public var festivalID: String?
    public var snapshot: FestivalLiveBoardSnapshot?
    public var viewState: ViewState = .idle
    public var isVisible = false
    public var generation = 0
    /// 독립 깃발 화면만 screen_view를 보낸다. 준비 가이드에 넣은 깃발 단계는 끈다.
    public var tracksScreenView = true

    public init(festivalID: String? = nil) {
      self.festivalID = festivalID
    }

    /// 로그아웃·인증 상실 때 이전 계정의 깃발 목록을 비운다.
    public mutating func clearAccountData() {
      snapshot = nil
      viewState = .idle
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case directory(FestivalFlagDirectory.Action)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case appeared
    case disappeared
    case refresh
    /// 부모가 선택 축제가 바뀌었음을 알린다.
    case festivalChanged(String?)
    /// 부모가 로그인 계정이 바뀌었음을 알린다.
    case accountChanged
    case tagSelected(FestivalFlagDirectory.Tag?)
    case sortTapped
    case sortSelected(FestivalFlagDirectory.Sort)
    case sortMenuDismissed
    case followTapped(
      id: String,
      follow: Bool,
      baseCount: Int?
    )
    case cardTapped(String)
  }

  // MARK: - AsyncAction

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(String, generation: Int, FestivalLiveBoardSnapshot)
    case failed(String, generation: Int, LoadFailure)
  }

  public enum LoadFailure: Equatable {
    case deviceNotRegistered
    case invalidFestivalID
    case invalidResponse
    case unavailable
  }

  private enum CancelID { case refresh }

  public var body: some ReducerOf<Self> {
    Scope(state: \.directory, action: \.directory) { FestivalFlagDirectory() }
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

      case .directory:
        return .none
      }
    }
    .syncFlagDirectory()
  }
}

// MARK: - 액션 처리

extension FestivalFlagFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .appeared:
      if state.tracksScreenView {
        analyticsUseCase.track(.screenView(
          screen: .festivalFlag,
          referrer: nil
        ))
      }
      state.isVisible = true
      return .send(.async(.load))

    case .disappeared:
      state.isVisible = false
      return .cancel(id: CancelID.refresh)

    case .refresh:
      return .send(.async(.load))

    case let .festivalChanged(id):
      guard state.festivalID != id else { return .none }
      state.festivalID = id
      state.snapshot = nil
      state.viewState = .idle
      state.generation += 1
      return state.isVisible ? .send(.async(.load)) : .cancel(id: CancelID.refresh)

    case .accountChanged:
      state.clearAccountData()
      state.generation += 1
      return state.isVisible ? .send(.async(.load)) : .cancel(id: CancelID.refresh)

    case let .tagSelected(tag):
      return .send(.directory(.view(.tagSelected(tag))))

    case .sortTapped:
      return .send(.directory(.view(.sortTapped)))

    case let .sortSelected(sort):
      return .send(.directory(.view(.sortSelected(sort))))

    case .sortMenuDismissed:
      return .send(.directory(.view(.sortMenuDismissed)))

    case let .followTapped(
      id,
      follow,
      baseCount
    ):
      return .send(.directory(.view(.followTapped(
        id: id,
        follow: follow,
        baseCount: baseCount
      ))))

    case let .cardTapped(id):
      return .send(.directory(.view(.cardTapped(id))))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .load:
      guard let id = state.festivalID else {
        state.viewState = .idle
        return .cancel(id: CancelID.refresh)
      }
      state.viewState = .loading
      let generation = state.generation
      return .run { send in
        do {
          await send(.inner(.loaded(
            id,
            generation: generation,
            try await liveBoardService.refresh(for: id)
          )))
        } catch FestivalLiveBoardError.deviceNotRegistered {
          await send(.inner(.failed(
            id,
            generation: generation,
            .deviceNotRegistered
          )))
        } catch FestivalLiveBoardError.invalidFestivalID {
          await send(.inner(.failed(
            id,
            generation: generation,
            .invalidFestivalID
          )))
        } catch FestivalLiveBoardError.invalidResponse {
          await send(.inner(.failed(
            id,
            generation: generation,
            .invalidResponse
          )))
        } catch let FestivalLiveBoardError.rateLimited(retryAfter) {
          // 라이브 보드와 같이 이전 목록을 유지한 채 기다렸다가 다시 불러온다.
          try await clock.sleep(for: .seconds(retryAfter))
          await send(.async(.load))
        } catch {
          await send(.inner(.failed(
            id,
            generation: generation,
            .unavailable
          )))
        }
      }
      .cancellable(
        id: CancelID.refresh,
        cancelInFlight: true
      )
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(id, generation, snapshot):
      guard state.festivalID == id, state.generation == generation, state.isVisible else { return .none }
      state.snapshot = snapshot
      state.viewState = .loaded
      return .none

    case let .failed(id, generation, failure):
      guard state.festivalID == id, state.generation == generation, state.isVisible else { return .none }
      switch failure {
      case .deviceNotRegistered: state.viewState = .deviceNotRegistered
      case .invalidFestivalID: state.viewState = .invalidFestivalID
      case .invalidResponse: state.viewState = .invalidResponse
      case .unavailable: state.viewState = .failed
      }
      return .none
    }
  }
}
