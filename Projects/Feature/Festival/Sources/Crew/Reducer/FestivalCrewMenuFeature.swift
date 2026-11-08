import ComposableArchitecture
import Foundation

/// Figma S07 크루장 메뉴 바텀시트. 고른 항목을 부모에게 알리고, 이름·크루원 선택 단계만 시트 안에서 바꾼다.
@Reducer
public struct FestivalCrewMenuFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    struct Member: Equatable, Identifiable {
      let id: String
      let nickname: String
    }

    let crewName: String
    /// 크루장을 뺀 크루원. 넘기기·내보내기 대상이다.
    let members: [Member]
    var step: Step = .menu
    var nameDraft: String

    init(
      crewName: String,
      members: [Member]
    ) {
      self.crewName = crewName
      self.members = members
      nameDraft = crewName
    }
  }

  /// 시트 안의 단계
  public enum Step: Equatable, Sendable {
    case menu
    case rename
    case transfer
    case remove
  }

  @CasePathable
  public enum Action: ViewAction, Equatable, BindableAction {
    case view(View)
    case binding(BindingAction<State>)
    case delegate(Delegate)
  }

  @CasePathable
  public enum View: Equatable {
    case renameTapped
    case rotateInviteTapped
    case transferTapped
    case removeTapped
    case dissolveTapped
    case saveNameTapped
    case memberTapped(String)
    case backTapped
  }

  @CasePathable
  public enum Delegate: Equatable {
    case rename(String)
    case rotateInvite
    case transfer(userID: String, nickname: String)
    case remove(userID: String, nickname: String)
    case dissolve
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case let .view(action):
        return handleViewAction(
          state: &state,
          action: action
        )
      case .binding, .delegate:
        return .none
      }
    }
  }
}

private extension FestivalCrewMenuFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .renameTapped:
      state.nameDraft = state.crewName
      state.step = .rename
      return .none
    case .rotateInviteTapped:
      return .send(.delegate(.rotateInvite))
    case .transferTapped:
      state.step = .transfer
      return .none
    case .removeTapped:
      state.step = .remove
      return .none
    case .dissolveTapped:
      return .send(.delegate(.dissolve))
    case .saveNameTapped:
      let name = state.nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
      guard state.canSaveName else { return .none }
      return .send(.delegate(.rename(name)))
    case let .memberTapped(id):
      guard let member = state.members.first(where: { $0.id == id }) else { return .none }
      switch state.step {
      case .transfer:
        return .send(.delegate(.transfer(
          userID: member.id,
          nickname: member.nickname
        )))
      case .remove:
        return .send(.delegate(.remove(
          userID: member.id,
          nickname: member.nickname
        )))
      case .menu, .rename:
        return .none
      }
    case .backTapped:
      state.step = .menu
      return .none
    }
  }
}

extension FestivalCrewMenuFeature.State {
  /// 크루 이름은 1~20자이고 지금 이름과 달라야 저장한다.
  var canSaveName: Bool {
    let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    return (1 ... 20).contains(name.count) && name != crewName
  }
}
