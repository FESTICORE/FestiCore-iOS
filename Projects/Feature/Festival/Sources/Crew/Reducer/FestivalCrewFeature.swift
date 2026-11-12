import ComposableArchitecture
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import Foundation

/// Figma S07 크루. 크루원 존·상태를 보고 내 상태와 집결을 보내며, 크루장은 메뉴에서 크루를 관리한다.
@Reducer
public struct FestivalCrewFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let crewID: String
    let zones: [FestivalPackDocument.Zone]
    /// 크루가 보관되는 시각. 서버와 같게 축제 마지막 날 종료 24시간 뒤로 잡는다.
    let archivesAt: Date?
    /// S07 I 안내 띠에 넣는 페스티벌 이름
    let festivalName: String?
    let sessionUserID: String?
    var crew: FestivalCrew?
    /// 크루원 존·상태. 라이브 보드 값으로 먼저 그리고 상세 응답으로 바꾼다.
    var live: FestivalLiveBoardSnapshot.Crew?
    var load: Load = .loading
    var isSendingStatus = false
    /// 모여 응답을 보내는 중. 응답이 올 때까지 다시 누르지 못한다.
    var isRespondingGather = false
    /// 서버가 확정한 내 모여 응답. 다음 상세 응답 전까지 버튼에 반영한다.
    var gatherReply: FestivalCrewGatherReply?
    /// 응답하려다 만료(409)를 받은 모여. 배너를 내린다.
    var expiredGatherID: String?
    var toast: Toast?
    /// 확인 팝업에서 확인을 누르면 실행할 크루장 동작
    var pendingConfirm: Confirm?
    @Presents var destination: Destination.State?

    public init(
      crewID: String,
      festival: FestivalPackDocument?,
      sessionUserID: String?,
      live: FestivalLiveBoardSnapshot.Crew? = nil
    ) {
      self.crewID = crewID
      zones = festival?.zones ?? []
      archivesAt = Self.archiveTime(festival)
      festivalName = festival?.name
      self.sessionUserID = sessionUserID
      self.live = live?.id == crewID ? live : nil
    }
  }

  public enum Load: Equatable, Sendable {
    case loading
    case loaded
    case failed
  }

  public enum Toast: Equatable, Sendable {
    case inviteRotated
    case renamed
    case transferred(String)
    case removed(String)
    case statusFailed
    case gatherExpired
  }

  public enum Confirm: Equatable, Sendable {
    case transfer(userID: String, nickname: String)
    case remove(userID: String, nickname: String)
    case dissolve
  }

  @Reducer(
    state: .equatable,
    action: .equatable
  )
  public enum Destination {
    case gather(FestivalCrewGatherFeature)
    case menu(FestivalCrewMenuFeature)
    case alert(FCConfirmAlert)
    case confirm(FCConfirmAlert)
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case destination(PresentationAction<Destination.Action>)
    case delegate(Delegate)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case backTapped
    case menuTapped
    case gatherTapped
    case stateTapped(FestivalCrewState)
    case gatherResponseTapped(FestivalCrewGatherResponse)
    case retryTapped
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
    case updateStatus(
      FestivalCrewState,
      zoneID: String?
    )
    case respondToGather(
      gatherID: String,
      response: FestivalCrewGatherResponse
    )
    case rotateInvite
    case rename(String)
    case transfer(userID: String, nickname: String)
    case remove(userID: String, nickname: String)
    case dissolve
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(FestivalCrew)
    case loadFailed(FestivalCrewError)
    case statusUpdated
    case statusFailed
    case gatherResponded(FestivalCrewGatherReply)
    case gatherResponseFailed(FestivalCrewError)
    case inviteRotated(FestivalCrewInviteCode)
    case crewChanged(FestivalCrew, Toast)
    case memberRemoved(userID: String, nickname: String)
    case dissolved
    case actionFailed(FestivalCrewError)
    case toastExpired
  }

  @CasePathable
  public enum Delegate: Equatable {
    case backRequested
    /// 해산했거나 크루에서 빠져 화면을 닫는다. 부모가 라이브 보드를 새로 받는다.
    case crewClosed
  }

  enum CancelID {
    case load
    case status
    case toast
  }

  static let toastDuration: Duration = .seconds(2)

  @Dependency(\.festivalCrewUseCase) private var useCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

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
          crewID: state.crewID,
          action: action
        )
      case let .inner(action):
        return handleInnerAction(
          state: &state,
          action: action
        )
      case let .destination(action):
        return handleDestinationAction(
          state: &state,
          action: action
        )
      case .delegate:
        return .none
      }
    }
    .ifLet(
      \.$destination,
      action: \.destination
    )
  }
}

extension FestivalCrewFeature.State {
  /// 크루장만 초대 링크와 크루장 메뉴를 쓴다.
  var isLeader: Bool {
    guard let sessionUserID else { return false }
    return (crew?.ownerID ?? live?.ownerID) == sessionUserID
  }

  /// 공유 시트로 보내는 초대 링크(`festicore://crew/<코드>`). 앱의 링크 처리가 S08 참여 확인을 연다.
  var inviteURL: URL? {
    guard isLeader, let code = crew?.inviteCode else { return nil }
    return URL(string: "festicore://crew/\(code)")
  }

  var title: String {
    return crew?.name ?? live?.name ?? "크루"
  }

  var myState: FestivalCrewState? {
    guard let sessionUserID else { return nil }
    let member = live?.members.first { $0.id == sessionUserID }
    return member?.state.flatMap(FestivalCrewState.init(rawValue:))
  }

  /// 내가 이 모여에 고른 응답. 방금 보낸 응답을 서버 목록보다 먼저 본다.
  func myGatherResponse(_ request: FestivalLiveBoardSnapshot.Crew.GatherRequest) -> FestivalCrewGatherResponse? {
    if let gatherReply, gatherReply.gatherID == request.id { return gatherReply.response }
    guard let sessionUserID else { return nil }
    return request.responses.first { $0.userID == sessionUserID }?.response
  }

  func zoneName(_ id: String?) -> String? {
    guard let id else { return nil }
    return zones.first { $0.id == id }?.name
  }

  static func archiveTime(_ festival: FestivalPackDocument?) -> Date? {
    let ends = (festival?.days ?? []).compactMap { $0.endsAt?.isoDate }
    return ends.max().map { $0.addingTimeInterval(24 * 60 * 60) }
  }
}

private extension FestivalCrewFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      guard state.crew == nil else { return .none }
      return .send(.async(.load))
    case .retryTapped:
      state.load = .loading
      return .send(.async(.load))
    case .backTapped:
      return .send(.delegate(.backRequested))
    case .menuTapped:
      guard state.isLeader else { return .none }
      let members = (state.live?.members ?? [])
        .filter { $0.id != state.sessionUserID }
        .map {
          FestivalCrewMenuFeature.State.Member(
            id: $0.id,
            nickname: $0.nickname
          )
        }
      state.destination = .menu(FestivalCrewMenuFeature.State(
        crewName: state.title,
        members: members
      ))
      return .none
    case .gatherTapped:
      let presentation = FestivalCrewPresentation(
        crew: state,
        now: date.now
      )
      guard presentation.canGather else { return .none }
      state.destination = .gather(FestivalCrewGatherFeature.State(
        crewID: state.crewID,
        zones: state.zones,
        availableAt: state.live?.gatherAvailableAt
      ))
      return .none
    case let .stateTapped(newState):
      return updateMyState(
        state: &state,
        newState: newState
      )
    case let .gatherResponseTapped(response):
      return respondToGather(
        state: &state,
        response: response
      )
    }
  }

  /// 받은 크루원만 응답한다. 보낸 사람·끝난 크루·응답 중에는 보내지 않는다.
  func respondToGather(
    state: inout State,
    response: FestivalCrewGatherResponse
  ) -> Effect<Action> {
    guard !state.isRespondingGather, state.crew?.archivedAt == nil,
          let sessionUserID = state.sessionUserID,
          let request = state.live?.gatherRequest, let gatherID = request.id,
          gatherID != state.expiredGatherID, request.byUserID != sessionUserID,
          state.myGatherResponse(request) != response else { return .none }
    state.isRespondingGather = true
    return .send(.async(.respondToGather(
      gatherID: gatherID,
      response: response
    )))
  }

  /// 누르면 바로 내 줄에 반영하고, 보내지 못하면 서버 값으로 다시 받는다.
  func updateMyState(
    state: inout State,
    newState: FestivalCrewState
  ) -> Effect<Action> {
    guard !state.isSendingStatus, state.myState != newState,
          let sessionUserID = state.sessionUserID, let live = state.live,
          let index = live.members.firstIndex(where: { $0.id == sessionUserID }) else { return .none }
    let member = live.members[index]
    var members = live.members
    members[index] = FestivalLiveBoardSnapshot.Crew.Member(
      id: member.id,
      nickname: member.nickname,
      state: newState.rawValue,
      zoneID: newState == .leaving ? nil : member.zoneID,
      updatedAt: date.now
    )
    state.live = live.replacing(members: members)
    state.isSendingStatus = true
    return .send(.async(.updateStatus(
      newState,
      zoneID: member.zoneID
    )))
  }

  func handleAsyncAction(
    crewID: String,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .load:
      return .run { send in
        do {
          await send(.inner(.loaded(try await useCase.detail(crewID: crewID))))
        } catch {
          await send(.inner(.loadFailed(Self.crewError(error))))
        }
      }
      .cancellable(
        id: CancelID.load,
        cancelInFlight: true
      )
    case let .updateStatus(
      newState,
      zoneID
    ):
      return .run { send in
        do {
          try await useCase.updateStatus(
            crewID: crewID,
            state: newState,
            zoneID: zoneID
          )
          await send(.inner(.statusUpdated))
        } catch {
          await send(.inner(.statusFailed))
        }
      }
      .cancellable(id: CancelID.status)
    case let .respondToGather(
      gatherID,
      response
    ):
      return .run { send in
        do {
          let reply = try await useCase.respondToGather(
            crewID: crewID,
            gatherID: gatherID,
            response: response
          )
          await send(.inner(.gatherResponded(reply)))
        } catch {
          await send(.inner(.gatherResponseFailed(Self.crewError(error))))
        }
      }
    case .rotateInvite:
      return perform { .inviteRotated(try await useCase.rotateInvite(crewID: crewID)) }
    case let .rename(name):
      return perform {
        let crew = try await useCase.rename(
          crewID: crewID,
          name: name
        )
        return .crewChanged(
          crew,
          .renamed
        )
      }
    case let .transfer(
      userID,
      nickname
    ):
      return perform {
        let crew = try await useCase.transfer(
          crewID: crewID,
          toUserID: userID
        )
        return .crewChanged(
          crew,
          .transferred(nickname)
        )
      }
    case let .remove(
      userID,
      nickname
    ):
      return perform {
        try await useCase.removeMember(
          crewID: crewID,
          userID: userID
        )
        return .memberRemoved(
          userID: userID,
          nickname: nickname
        )
      }
    case .dissolve:
      return perform {
        try await useCase.dissolve(crewID: crewID)
        return .dissolved
      }
    }
  }

  /// 크루장 동작 한 번을 보내고 결과나 실패를 내부 액션으로 돌려준다.
  func perform(_ operation: @escaping @Sendable () async throws -> InnerAction) -> Effect<Action> {
    return .run { send in
      do {
        await send(.inner(try await operation()))
      } catch {
        await send(.inner(.actionFailed(Self.crewError(error))))
      }
    }
  }

  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(crew):
      state.crew = crew
      if let live = crew.live { state.live = live }
      state.load = .loaded
      return .none
    case let .loadFailed(error):
      // 크루에서 빠졌거나 크루가 없어졌으면 화면을 닫는다.
      if error == .forbidden || error == .notFound { return .send(.delegate(.crewClosed)) }
      state.load = state.live == nil ? .failed : .loaded
      return .none
    case .statusUpdated:
      state.isSendingStatus = false
      return .none
    case .statusFailed:
      state.isSendingStatus = false
      return .merge(
        show(
          .statusFailed,
          state: &state
        ),
        .send(.async(.load))
      )
    case let .gatherResponded(reply):
      state.isRespondingGather = false
      state.gatherReply = reply
      return .none
    case let .gatherResponseFailed(error):
      state.isRespondingGather = false
      if error == .gatherExpired {
        state.expiredGatherID = state.live?.gatherRequest?.id
        return .merge(
          show(
            .gatherExpired,
            state: &state
          ),
          .send(.async(.load))
        )
      }
      state.destination = .alert(.alert(
        title: "모여에 응답하지 못했어요",
        message: Self.gatherMessage(error),
        confirmTitle: "확인",
        cancelTitle: "닫기"
      ))
      return .none
    case let .inviteRotated(code):
      state.crew = state.crew?.replacing(invite: code)
      return show(
        .inviteRotated,
        state: &state
      )
    case let .crewChanged(
      crew,
      toast
    ):
      state.crew = crew
      state.live = state.live?.replacing(
        name: crew.name,
        ownerID: crew.ownerID
      )
      return show(
        toast,
        state: &state
      )
    case let .memberRemoved(
      userID,
      nickname
    ):
      if let live = state.live {
        state.live = live.replacing(members: live.members.filter { $0.id != userID })
      }
      return .merge(
        show(
          .removed(nickname),
          state: &state
        ),
        .send(.async(.load))
      )
    case .dissolved:
      return .send(.delegate(.crewClosed))
    case let .actionFailed(error):
      state.destination = .alert(.alert(
        title: "요청하지 못했어요",
        message: Self.message(error),
        confirmTitle: "확인",
        cancelTitle: "닫기"
      ))
      return .none
    case .toastExpired:
      state.toast = nil
      return .none
    }
  }

  /// 토스트를 띄우고 잠시 뒤 지운다. 새 토스트가 오면 이전 타이머를 끊는다.
  func show(
    _ toast: Toast,
    state: inout State
  ) -> Effect<Action> {
    state.toast = toast
    return .run { send in
      try await clock.sleep(for: Self.toastDuration)
      await send(.inner(.toastExpired))
    }
    .cancellable(
      id: CancelID.toast,
      cancelInFlight: true
    )
  }

  func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.gather(.delegate(.gathered))):
      state.destination = nil
      return .send(.async(.load))
    case let .presented(.menu(.delegate(delegate))):
      return handleMenuDelegate(
        state: &state,
        delegate: delegate
      )
    case .presented(.confirm(.confirmTapped)):
      let confirm = state.pendingConfirm
      state.pendingConfirm = nil
      state.destination = nil
      return confirmed(confirm)
    case .presented(.confirm(.cancelTapped)), .presented(.alert):
      state.pendingConfirm = nil
      state.destination = nil
      return .none
    case .dismiss:
      state.pendingConfirm = nil
      return .none
    case .presented:
      return .none
    }
  }

  func confirmed(_ confirm: Confirm?) -> Effect<Action> {
    switch confirm {
    case let .transfer(
      userID,
      nickname
    ):
      return .send(.async(.transfer(
        userID: userID,
        nickname: nickname
      )))
    case let .remove(
      userID,
      nickname
    ):
      return .send(.async(.remove(
        userID: userID,
        nickname: nickname
      )))
    case .dissolve:
      return .send(.async(.dissolve))
    case nil:
      return .none
    }
  }

  func handleMenuDelegate(
    state: inout State,
    delegate: FestivalCrewMenuFeature.Delegate
  ) -> Effect<Action> {
    state.destination = nil
    switch delegate {
    case let .rename(name):
      return .send(.async(.rename(name)))
    case .rotateInvite:
      return .send(.async(.rotateInvite))
    case let .transfer(
      userID,
      nickname
    ):
      state.pendingConfirm = .transfer(
        userID: userID,
        nickname: nickname
      )
      state.destination = .confirm(.alert(
        title: "\(nickname)님에게 크루장을 넘길까요?",
        message: "넘긴 뒤에는 크루장 메뉴를 쓸 수 없어요.",
        confirmTitle: "넘기기"
      ))
    case let .remove(
      userID,
      nickname
    ):
      state.pendingConfirm = .remove(
        userID: userID,
        nickname: nickname
      )
      state.destination = .confirm(.alert(
        title: "\(nickname)님을 내보낼까요?",
        message: "내보낸 크루원은 이 크루의 존과 상태를 볼 수 없어요.",
        confirmTitle: "내보내기"
      ))
    case .dissolve:
      state.pendingConfirm = .dissolve
      state.destination = .confirm(.alert(
        title: "크루를 해산할까요?",
        message: "모든 크루원이 크루에서 나가요. 해산한 크루는 되돌릴 수 없어요.",
        confirmTitle: "해산하기"
      ))
    }
    return .none
  }

  static func crewError(_ error: any Error) -> FestivalCrewError {
    return error as? FestivalCrewError ?? .unavailable
  }

  static func message(_ error: FestivalCrewError) -> String {
    switch error {
    case .forbidden: return "크루장만 할 수 있어요."
    case .festivalEnded: return "끝난 페스티벌의 크루는 바꿀 수 없어요."
    case .unauthenticated: return "로그인 상태를 확인해 주세요."
    case .termsRequired: return "최신 이용약관에 동의한 뒤 다시 시도해 주세요."
    case .invalidInput: return "크루 이름은 1~\(FestivalCrew.maxNameLength)자로 입력해 주세요."
    default: return "연결을 확인한 뒤 다시 시도해 주세요."
    }
  }

  static func gatherMessage(_ error: FestivalCrewError) -> String {
    switch error {
    case .forbidden: return "이 모여에는 응답할 수 없어요."
    case .festivalEnded: return "끝난 페스티벌의 크루는 바꿀 수 없어요."
    case .unauthenticated: return "로그인 상태를 확인해 주세요."
    case .termsRequired: return "최신 이용약관에 동의한 뒤 다시 시도해 주세요."
    case .notFound: return "모여 요청을 찾지 못했어요."
    default: return "연결을 확인한 뒤 다시 시도해 주세요."
    }
  }
}

private extension FestivalLiveBoardSnapshot.Crew {
  func replacing(members: [Member]) -> Self {
    return Self(
      id: id,
      name: name,
      members: members,
      ownerID: ownerID,
      gatherRequest: gatherRequest,
      gatherAvailableAt: gatherAvailableAt
    )
  }

  func replacing(
    name: String,
    ownerID: String
  ) -> Self {
    return Self(
      id: id,
      name: name,
      members: members,
      ownerID: ownerID,
      gatherRequest: gatherRequest,
      gatherAvailableAt: gatherAvailableAt
    )
  }
}

private extension FestivalCrew {
  func replacing(invite: FestivalCrewInviteCode) -> Self {
    return Self(
      id: id,
      festivalID: festivalID,
      name: name,
      ownerID: ownerID,
      members: members,
      inviteCode: invite.code,
      inviteExpiresAt: invite.expiresAt,
      live: live,
      archivedAt: archivedAt
    )
  }
}
