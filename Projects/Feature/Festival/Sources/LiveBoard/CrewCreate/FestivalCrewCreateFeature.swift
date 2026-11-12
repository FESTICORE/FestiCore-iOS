import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation

@Reducer
public struct FestivalCrewCreateFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 이름 입력 → 만든 뒤 초대 공유
    public enum Step: Equatable {
      case naming
      case created(FestivalCrew)
    }

    public let festivalID: String
    /// S07 B 안내 "원더리벳 2026이 끝나면 기록만 남아요"에 넣는 페스티벌 이름
    public let festivalName: String?
    public var name = ""
    public var isSubmitting = false
    public var step: Step = .naming
    /// 다시 시도로 풀리지 않는 실패(이미 크루가 있음·끝난 페스티벌 등) 안내
    public var errorMessage: String?
    @Presents public var alert: FCAlertState<FCAlertAction>?

    public init(
      festivalID: String,
      festivalName: String? = nil
    ) {
      self.festivalID = festivalID
      self.festivalName = festivalName
    }

    public var canSubmit: Bool {
      let count = name.trimmingCharacters(in: .whitespacesAndNewlines).count
      return (1 ... FestivalCrew.maxNameLength).contains(count) && !isSubmitting
    }

    /// 크루장 전용 초대 링크(`festicore://crew/<코드>`). S08 참여 확인 경로와 같다.
    public var inviteURL: URL? {
      guard case let .created(crew) = step, let code = crew.inviteCode else { return nil }
      return URL(string: "festicore://crew/\(code)")
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
    case openCrewTapped
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
    case createFailed(FestivalCrewError)
  }

  // MARK: - Delegate

  @CasePathable
  public enum Delegate: Equatable {
    /// 만들었다. 화면은 초대 단계로 남고 부모는 라이브 보드를 다시 읽는다.
    case created(FestivalCrew)
    /// 크루 화면(S07)으로 간다.
    case openCrewRequested(crewID: String)
    case loginRequested
    case closeRequested
  }

  @Dependency(\.festivalCrewUseCase) private var crewUseCase

  private enum CancelID { case create }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )
      case let .async(asyncAction):
        return handleAsyncAction(action: asyncAction)
      case let .inner(innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )
      case let .delegate(delegateAction):
        return handleDelegateAction(delegateAction)
      case .alert(.presented(.confirmTapped)):
        state.alert = nil
        return .send(.view(.submitTapped))
      case .alert:
        state.alert = nil
        return .none
      }
    }
    .ifLet(
      \.$alert,
      action: \.alert
    ) { FCConfirmAlert() }
  }
}

private extension FestivalCrewCreateFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .nameChanged(name):
      state.name = String(name.prefix(FestivalCrew.maxNameLength))
      state.errorMessage = nil
      return .none
    case .submitTapped:
      guard state.canSubmit else { return .none }
      state.isSubmitting = true
      let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
      return .send(.async(.create(
        festivalID: state.festivalID,
        name: name
      )))
    case .closeTapped:
      guard !state.isSubmitting else { return .none }
      return .send(.delegate(.closeRequested))
    case .openCrewTapped:
      guard case let .created(crew) = state.step else { return .none }
      return .send(.delegate(.openCrewRequested(crewID: crew.id)))
    }
  }

  func handleAsyncAction(action: AsyncAction) -> Effect<Action> {
    switch action {
    case let .create(
      festivalID,
      name
    ):
      return .run { send in
        do {
          let crew = try await crewUseCase.create(
            festivalID: festivalID,
            name: name,
            nickname: nil
          )
          await send(.inner(.createSucceeded(crew)))
        } catch {
          await send(.inner(.createFailed(error as? FestivalCrewError ?? .unavailable)))
        }
      }
      .cancellable(id: CancelID.create)
    }
  }

  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .createSucceeded(crew):
      state.isSubmitting = false
      state.step = .created(crew)
      return .send(.delegate(.created(crew)))
    case let .createFailed(error):
      state.isSubmitting = false
      if error == .unauthenticated { return .send(.delegate(.loginRequested)) }
      if let message = Self.message(for: error) {
        state.errorMessage = message
        return .none
      }
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
    case .created, .openCrewRequested, .loginRequested, .closeRequested:
      return .none
    }
  }

  /// 다시 시도해도 같은 실패. 입력란 아래에 알린다. 일시 오류는 nil(다시 시도 알림).
  static func message(for error: FestivalCrewError) -> String? {
    switch error {
    case .alreadyInCrew:
      return "이 페스티벌에서 이미 크루에 있어요. 크루는 페스티벌마다 하나만 만들거나 참여할 수 있어요."
    case .festivalEnded:
      return "끝난 페스티벌에는 크루를 만들 수 없어요."
    case .invalidInput:
      return "크루 이름을 1~\(FestivalCrew.maxNameLength)자로 입력해 주세요."
    case .termsRequired:
      return "최신 이용약관에 동의한 뒤 다시 시도해 주세요."
    case .unauthenticated, .invalidResponse, .forbidden, .cooldown, .unavailable, .notFound, .full, .gatherExpired:
      return nil
    }
  }
}
