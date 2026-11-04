import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation

@Reducer
public struct FestivalCrewCreateFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    public var name = ""
    public var isSubmitting = false
    @Presents public var alert: FCAlertState<FCAlertAction>?

    public init(festivalID: String) {
      self.festivalID = festivalID
    }

    public var canSubmit: Bool {
      let count = name.trimmingCharacters(in: .whitespacesAndNewlines).count
      return (1 ... 20).contains(count) && !isSubmitting
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(Delegate)
    case alert(PresentationAction<FCAlertAction>)
  }

  // MARK: - View

  @CasePathable
  public enum View: Equatable {
    case nameChanged(String)
    case submitTapped
    case closeTapped
  }

  // MARK: - Async

  @CasePathable
  public enum AsyncAction: Equatable {
    case create(festivalID: String, name: String)
  }

  // MARK: - Inner

  @CasePathable
  public enum InnerAction: Equatable {
    case createSucceeded(FestivalCrew)
    case createFailed
  }

  // MARK: - Delegate

  @CasePathable
  public enum Delegate: Equatable {
    case created(FestivalCrew)
    case closeRequested
  }

  @Dependency(\.festivalCrewUseCase) private var crewUseCase

  private enum CancelID { case create }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(state: &state, action: viewAction)
      case let .async(asyncAction):
        return handleAsyncAction(action: asyncAction)
      case let .inner(innerAction):
        return handleInnerAction(state: &state, action: innerAction)
      case let .delegate(delegateAction):
        return handleDelegateAction(delegateAction)
      case .alert(.presented(.confirmTapped)):
        return .send(.view(.submitTapped))
      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert) { FCConfirmAlert() }
  }
}

private extension FestivalCrewCreateFeature {
  func handleViewAction(state: inout State, action: View) -> Effect<Action> {
    switch action {
    case let .nameChanged(name):
      state.name = String(name.prefix(20))
      return .none
    case .submitTapped:
      guard state.canSubmit else { return .none }
      state.isSubmitting = true
      let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
      return .send(.async(.create(festivalID: state.festivalID, name: name)))
    case .closeTapped:
      guard !state.isSubmitting else { return .none }
      return .send(.delegate(.closeRequested))
    }
  }

  func handleAsyncAction(action: AsyncAction) -> Effect<Action> {
    switch action {
    case let .create(festivalID, name):
      return .run { send in
        do {
          let crew = try await crewUseCase.create(festivalID: festivalID, name: name, nickname: nil)
          await send(.inner(.createSucceeded(crew)))
        } catch {
          await send(.inner(.createFailed))
        }
      }
      .cancellable(id: CancelID.create)
    }
  }

  func handleInnerAction(state: inout State, action: InnerAction) -> Effect<Action> {
    switch action {
    case let .createSucceeded(crew):
      state.isSubmitting = false
      return .send(.delegate(.created(crew)))
    case .createFailed:
      state.isSubmitting = false
      state.alert = .alert(
        title: "크루를 만들지 못했어요",
        message: "연결을 확인하고 다시 시도해 주세요.",
        confirmTitle: "다시 시도",
        cancelTitle: "닫기"
      )
      return .none
    }
  }

  func handleDelegateAction(_ action: Delegate) -> Effect<Action> {
    switch action {
    case .created, .closeRequested:
      return .none
    }
  }
}
