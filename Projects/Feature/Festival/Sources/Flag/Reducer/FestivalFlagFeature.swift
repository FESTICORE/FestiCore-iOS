import ComposableArchitecture
import FestivalDomainInterface

@Reducer
public struct FestivalFlagFeature {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService
  @Dependency(\.continuousClock) private var clock

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
  public enum Action: Equatable {
    case appeared
    case disappeared
    case directory(FestivalFlagDirectory.Action)
    case festivalChanged(String?)
    case refresh
    case accountChanged
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
      case .appeared:
        state.isVisible = true
        return load(&state)

      case .disappeared:
        state.isVisible = false
        return .cancel(id: CancelID.refresh)

      case .directory:
        return .none

      case let .festivalChanged(id):
        guard state.festivalID != id else { return .none }
        state.festivalID = id
        state.snapshot = nil
        state.viewState = .idle
        state.generation += 1
        return state.isVisible ? load(&state) : .cancel(id: CancelID.refresh)

      case .refresh:
        return load(&state)

      case .accountChanged:
        state.clearAccountData()
        state.generation += 1
        return state.isVisible ? load(&state) : .cancel(id: CancelID.refresh)

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
    .syncFlagDirectory()
  }

  private func load(_ state: inout State) -> Effect<Action> {
    guard let id = state.festivalID else {
      state.viewState = .idle
      return .cancel(id: CancelID.refresh)
    }
    state.viewState = .loading
    let generation = state.generation
    return .run { send in
      do {
        await send(.loaded(id, generation: generation, try await liveBoardService.refresh(for: id)))
      } catch FestivalLiveBoardError.deviceNotRegistered {
        await send(.failed(id, generation: generation, .deviceNotRegistered))
      } catch FestivalLiveBoardError.invalidFestivalID {
        await send(.failed(id, generation: generation, .invalidFestivalID))
      } catch FestivalLiveBoardError.invalidResponse {
        await send(.failed(id, generation: generation, .invalidResponse))
      } catch let FestivalLiveBoardError.rateLimited(retryAfter) {
        // 라이브 보드와 같이 이전 목록을 유지한 채 기다렸다가 다시 불러온다.
        try await clock.sleep(for: .seconds(retryAfter))
        await send(.refresh)
      } catch {
        await send(.failed(id, generation: generation, .unavailable))
      }
    }
    .cancellable(id: CancelID.refresh, cancelInFlight: true)
  }
}
