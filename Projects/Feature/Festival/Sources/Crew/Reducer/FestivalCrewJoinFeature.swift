import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation

/// Figma S08 크루 참여 확인. 초대 링크의 크루를 미리 보고 참여하거나 닫는다.
@Reducer
public struct FestivalCrewJoinFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let code: String
    var hasSession: Bool
    var invite: FestivalCrewInvite?
    var load: Load = .loading
    var isJoining = false
    @Presents var alert: FCAlertState<FCAlertAction>?

    public init(
      code: String,
      hasSession: Bool
    ) {
      self.code = code
      self.hasSession = hasSession
    }
  }

  /// 불러온 초대로는 참여할 수 없는 까닭(Figma S08 B 만료·C 정원 초과). 참여 대신 닫기만 둔다.
  public enum Blocker: Equatable, Sendable {
    case expired
    case full
  }

  public enum Load: Equatable, Sendable {
    case loading
    case loaded
    /// 없거나 만료된 초대
    case unavailable
    /// 연결 실패. 다시 시도할 수 있다.
    case failed
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case alert(PresentationAction<FCAlertAction>)
    case delegate(Delegate)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case retryTapped
    case cancelTapped
    case joinTapped
    case sessionChanged(Bool)
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
    case join
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(FestivalCrewInvite)
    case loadFailed(FestivalCrewError)
    case joined(FestivalCrew)
    case joinFailed(FestivalCrewError)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case closeRequested
    case loginRequested
    /// 참여했다. 부모가 크루 화면(S07)을 연다.
    case joined(crewID: String, festivalID: String)
  }

  @Dependency(\.festivalCrewUseCase) private var useCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(action):
        return handleViewAction(
          state: &state,
          action: action
        )
      case let .async(action):
        return handleAsyncAction(
          code: state.code,
          action: action
        )
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

private extension FestivalCrewJoinFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      guard state.invite == nil else { return .none }
      return .send(.async(.load))
    case .retryTapped:
      state.load = .loading
      return .send(.async(.load))
    case .cancelTapped:
      return .send(.delegate(.closeRequested))
    case .joinTapped:
      guard state.load == .loaded, !state.isJoining else { return .none }
      guard state.hasSession else { return .send(.delegate(.loginRequested)) }
      state.isJoining = true
      return .send(.async(.join))
    case let .sessionChanged(hasSession):
      state.hasSession = hasSession
      return .none
    }
  }

  func handleAsyncAction(
    code: String,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .load:
      return .run { send in
        do {
          await send(.inner(.loaded(try await useCase.invite(code: code))))
        } catch {
          await send(.inner(.loadFailed(error as? FestivalCrewError ?? .unavailable)))
        }
      }
    case .join:
      return .run { send in
        do {
          await send(.inner(.joined(try await useCase.join(inviteCode: code))))
        } catch {
          await send(.inner(.joinFailed(error as? FestivalCrewError ?? .unavailable)))
        }
      }
    }
  }

  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(invite):
      state.invite = invite
      state.load = .loaded
      return .none
    case let .loadFailed(error):
      state.load = error == .notFound || error == .festivalEnded ? .unavailable : .failed
      return .none
    case let .joined(crew):
      state.isJoining = false
      return .send(.delegate(.joined(
        crewID: crew.id,
        festivalID: crew.festivalID
      )))
    case let .joinFailed(error):
      state.isJoining = false
      if error == .unauthenticated { return .send(.delegate(.loginRequested)) }
      state.alert = .alert(
        title: "크루에 참여하지 못했어요",
        message: Self.message(error),
        confirmTitle: "확인",
        cancelTitle: "닫기"
      )
      return .none
    }
  }

  static func message(_ error: FestivalCrewError) -> String {
    switch error {
    case .alreadyInCrew: return "이 페스티벌에서 이미 다른 크루에 있어요. 지금 크루에서 나간 뒤 다시 시도해 주세요."
    case .full: return "크루 정원 \(FestivalCrew.maxMembers)명이 모두 찼어요."
    case .notFound, .festivalEnded: return "초대가 만료됐어요. 크루장에게 새 초대 링크를 받아 주세요."
    case .termsRequired: return "최신 이용약관에 동의한 뒤 다시 시도해 주세요."
    default: return "연결을 확인한 뒤 다시 시도해 주세요."
    }
  }
}

extension FestivalCrewJoinFeature.State {
  func blocker(now: Date) -> FestivalCrewJoinFeature.Blocker? {
    guard let invite else { return nil }
    if invite.expiresAt <= now { return .expired }
    if invite.memberCount >= FestivalCrew.maxMembers { return .full }
    return nil
  }
}
