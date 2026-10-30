import ComposableArchitecture
import FestivalDomainInterface

@Reducer
public struct FestivalFlagFeature {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService

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

    public var festivalID: String?
    public var snapshot: FestivalLiveBoardSnapshot?
    public var viewState: ViewState = .idle
    public var isVisible = false

    public init(festivalID: String? = nil) {
      self.festivalID = festivalID
    }
  }

  @CasePathable
  public enum Action: Equatable {
    case appeared
    case disappeared
    case festivalChanged(String?)
    case refresh
    case loaded(String, FestivalLiveBoardSnapshot)
    case failed(String, LoadFailure)
  }

  public enum LoadFailure: Equatable {
    case deviceNotRegistered
    case invalidFestivalID
    case invalidResponse
    case unavailable
  }

  private enum CancelID { case refresh }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .appeared:
        state.isVisible = true
        return load(&state)

      case .disappeared:
        state.isVisible = false
        return .cancel(id: CancelID.refresh)

      case let .festivalChanged(id):
        guard state.festivalID != id else { return .none }
        state.festivalID = id
        state.snapshot = nil
        state.viewState = .idle
        return state.isVisible ? load(&state) : .cancel(id: CancelID.refresh)

      case .refresh:
        return load(&state)

      case let .loaded(id, snapshot):
        guard state.festivalID == id, state.isVisible else { return .none }
        state.snapshot = snapshot
        state.viewState = .loaded
        return .none

      case let .failed(id, failure):
        guard state.festivalID == id, state.isVisible else { return .none }
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

  private func load(_ state: inout State) -> Effect<Action> {
    guard let id = state.festivalID else {
      state.viewState = .idle
      return .cancel(id: CancelID.refresh)
    }
    state.viewState = .loading
    return .run { send in
      do {
        await send(.loaded(id, try await liveBoardService.refresh(for: id)))
      } catch FestivalLiveBoardError.deviceNotRegistered {
        await send(.failed(id, .deviceNotRegistered))
      } catch FestivalLiveBoardError.invalidFestivalID {
        await send(.failed(id, .invalidFestivalID))
      } catch FestivalLiveBoardError.invalidResponse {
        await send(.failed(id, .invalidResponse))
      } catch {
        await send(.failed(id, .unavailable))
      }
    }
    .cancellable(id: CancelID.refresh, cancelInFlight: true)
  }
}
