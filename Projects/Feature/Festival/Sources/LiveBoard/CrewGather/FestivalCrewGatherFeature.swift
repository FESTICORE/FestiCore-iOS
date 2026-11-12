import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation

@Reducer
public struct FestivalCrewGatherFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    let crewID: String
    let zones: [FestivalPackDocument.Zone]
    var selectedZoneID: String?
    var isSubmitting = false
    var availableAt: Date?
    /// 소리 알림을 받을 크루원 수(나 제외). 모르면 숫자 없이 안내한다.
    var recipientCount: Int?
    @Presents var alert: FCAlertState<FCAlertAction>?
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(Delegate)
    case alert(PresentationAction<FCAlertAction>)
  }
  @CasePathable
  public enum View: Equatable {
    /// Figma S07 E: 존 타일을 누르면 바로 집결을 요청한다.
    case zoneTapped(String)
  }
  @CasePathable
  public enum AsyncAction: Equatable {
    case gather(crewID: String, zoneID: String)
  }
  @CasePathable
  public enum InnerAction: Equatable {
    case succeeded
    case failed(FestivalCrewError)
  }
  @CasePathable
  public enum Delegate: Equatable { case gathered }

  @Dependency(\.festivalCrewUseCase) private var useCase
  @Dependency(\.date) private var date

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(action):
        return handleViewAction(
          state: &state,
          action: action
        )
      case let .async(action):
        return handleAsyncAction(action)
      case let .inner(action):
        return handleInnerAction(
          state: &state,
          action: action
        )
      case .alert:
        state.alert = nil
        return .none
      case .delegate:
        return .none
      }
    }
    .ifLet(
      \.$alert,
      action: \.alert
    ) { FCConfirmAlert() }
  }
}

private extension FestivalCrewGatherFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .zoneTapped(zoneID):
      guard !state.isSubmitting, state.zones.contains(where: { $0.id == zoneID }) else { return .none }
      if let availableAt = state.availableAt, availableAt > date.now {
        state.alert = .alert(
          title: "잠시 후 다시 모일 수 있어요",
          message: "크루 집결은 10분에 한 번 요청할 수 있어요."
        )
        return .none
      }
      state.selectedZoneID = zoneID
      state.isSubmitting = true
      return .send(.async(.gather(
        crewID: state.crewID,
        zoneID: zoneID
      )))
    }
  }

  func handleAsyncAction(_ action: AsyncAction) -> Effect<Action> {
    switch action {
    case let .gather(
      crewID,
      zoneID
    ):
      return .run { send in
        do {
          try await useCase.gather(
            crewID: crewID,
            zoneID: zoneID
          )
          await send(.inner(.succeeded))
        } catch let error as FestivalCrewError {
          await send(.inner(.failed(error)))
        } catch {
          await send(.inner(.failed(.unavailable)))
        }
      }
    }
  }

  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    state.isSubmitting = false
    switch action {
    case .succeeded:
      return .send(.delegate(.gathered))
    case let .failed(error):
      let message: String
      switch error {
      case .cooldown: message = "크루 집결은 10분에 한 번 요청할 수 있어요. 잠시 후 다시 시도해 주세요."
      case .unauthenticated: message = "로그인 상태를 확인해 주세요."
      case .termsRequired: message = "최신 이용약관에 동의한 뒤 다시 시도해 주세요."
      case .forbidden: message = "현재 크루 멤버만 집결을 요청할 수 있어요."
      case .festivalEnded: message = "종료된 페스티벌에서는 집결을 요청할 수 없어요."
      default: message = "연결과 선택한 존을 확인한 뒤 다시 시도해 주세요."
      }
      state.alert = .alert(
        title: "집결을 요청하지 못했어요",
        message: message
      )
      return .none
    }
  }
}
