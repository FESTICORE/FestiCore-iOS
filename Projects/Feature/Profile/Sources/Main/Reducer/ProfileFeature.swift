//
//  ProfileFeature.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import ProfileInterface
import UIKit

@Reducer
public struct ProfileFeature {
  private let legalBaseURL: URL?

  public init(legalBaseURL: URL? = nil) {
    self.legalBaseURL = legalBaseURL
  }

  @ObservableState
  public struct State: Equatable {
    /// 앱이 `accountChanged`로 알려 주는 계정 상태
    public var profile: AuthProfile?
    public var hasSession = false
    public var isLoading = false
    public var message: String?
    /// 기기에 받아 둔 팩
    public var packs: [FestivalReceivedPack] = []
    public var packLoad = PackLoad.idle
    /// 아직 연결되지 않은 이동은 누를 수 없게 둔다.
    public var isBearerNavigationAvailable = false
    public var isSearchAvailable = false
    public var isLockScreenAvailable = false
    public var isNoticeAvailable = false

    public var isAccountPresented = false
    /// 로그아웃·회원 탈퇴·문서 안내 확인 팝업. 계정 시트 위에 `fcAlert`로 띄운다.
    @Presents public var destination: Destination.State?
    /// 지금 띄운 확인 팝업이 무엇을 확인하는지
    public var confirmation: Confirmation?

    public init() {}
  }

  /// 받은 팩 목록을 읽는 상태. 처음 읽는 동안만 스켈레톤을 보인다.
  public enum PackLoad: Equatable {
    case idle
    case loading
    case loaded
    case failed
  }

  private enum CancelID { case packs }

  public enum Confirmation: Equatable, Sendable {
    case logout
    case withdraw
    case legalLinkUnavailable
  }

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
    case packDetail(PackDetailFeature)
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case destination(PresentationAction<Destination.Action>)
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    /// 앱 코디네이터가 계정 상태가 바뀔 때 보내는 입력
    case accountChanged(profile: AuthProfile?, hasSession: Bool, isLoading: Bool, message: String?)
    case onAppear
    case packsRetryTapped
    case bearerTapped
    case searchTapped
    case packTapped(String)
    case notificationsTapped
    case lockScreenTapped
    case accountTapped
    case accountDismissed
    case refreshTapped
    case logoutTapped
    case withdrawTapped
    case noticeTapped
    case termsTapped
    case privacyTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case fetchPacks
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case packsLoaded([FestivalReceivedPack])
    /// 서버 목록으로 새 버전 여부를 갱신한 결과
    case packsRefreshed([FestivalReceivedPack])
    case packsFailed
  }

  // MARK: - DelegateAction

  /// 이동 계약은 ProfileInterface에 있다.
  public typealias DelegateAction = ProfileDelegate

  @Dependency(\.festivalReceivedPackUseCase) private var receivedPackUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination(let destinationAction):
        return handleDestinationAction(state: &state, action: destinationAction)

      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .delegate(let delegateAction):
        return handleDelegateAction(state: &state, action: delegateAction)
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension ProfileFeature.Destination.State: Equatable {}
extension ProfileFeature.Destination.Action: Equatable {}

extension ProfileFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .accountChanged(profile, hasSession, isLoading, message):
      let lostSession = state.hasSession && !hasSession
      state.profile = profile
      state.hasSession = hasSession
      state.isLoading = isLoading
      state.message = message
      // 로그아웃되면 열려 있던 계정 시트와 확인 팝업을 닫는다.
      if lostSession && state.isAccountPresented {
        return .send(.view(.accountDismissed))
      }
      return .none

    case .onAppear:
      guard state.packLoad != .loading else { return .none }
      // 이미 보여 준 목록은 다시 읽는 동안 그대로 둔다.
      if state.packLoad != .loaded { state.packLoad = .loading }
      return .send(.async(.fetchPacks))

    case .packsRetryTapped:
      guard state.packLoad == .failed else { return .none }
      state.packLoad = .loading
      return .send(.async(.fetchPacks))

    case .bearerTapped:
      return .send(.delegate(.bearerRequested))

    case .searchTapped:
      return .send(.delegate(.searchRequested))

    case .packTapped(let id):
      guard let pack = state.packs.first(where: { $0.id == id }) else { return .none }
      state.destination = .packDetail(.init(festivalID: pack.id, title: pack.name))
      return .none

    case .notificationsTapped:
      return open(URL(string: UIApplication.openSettingsURLString))

    case .lockScreenTapped:
      return .send(.delegate(.lockScreenRequested))

    case .accountTapped:
      guard state.profile != nil || state.hasSession else {
        return .send(.delegate(.loginRequested))
      }
      state.isAccountPresented = true
      return .none

    case .accountDismissed:
      state.isAccountPresented = false
      if state.confirmation == .logout || state.confirmation == .withdraw {
        state.destination = nil
        state.confirmation = nil
      }
      return .none

    case .refreshTapped:
      return .send(.delegate(.profileRefreshRequested))

    case .logoutTapped:
      presentConfirmation(.logout, state: &state)
      return .none

    case .withdrawTapped:
      presentConfirmation(.withdraw, state: &state)
      return .none

    case .noticeTapped:
      return .send(.delegate(.noticeRequested))

    case .termsTapped:
      return openLegalURL(path: "terms", state: &state)

    case .privacyTapped:
      return openLegalURL(path: "privacy", state: &state)
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .fetchPacks:
      return .run { send in
        do {
          await send(.inner(.packsLoaded(try await receivedPackUseCase.receivedPacks())))
        } catch {
          await send(.inner(.packsFailed))
          return
        }
        // 서버 목록을 받지 못하면 저장된 목록 기준으로 보여 준 값을 유지한다.
        if let refreshed = try? await receivedPackUseCase.refreshReceivedPacks() {
          await send(.inner(.packsRefreshed(refreshed)))
        }
      }
      .cancellable(id: CancelID.packs, cancelInFlight: true)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .packsLoaded(let packs), .packsRefreshed(let packs):
      state.packs = packs
      state.packLoad = .loaded
      return .none

    case .packsFailed:
      // 이미 보여 준 목록이 있으면 실패로 바꾸지 않는다.
      if state.packLoad != .loaded { state.packLoad = .failed }
      return .none
    }
  }

  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.alert(.confirmTapped)):
      let confirmation = state.confirmation
      state.destination = nil
      state.confirmation = nil
      switch confirmation {
      case .logout: return .send(.delegate(.logoutRequested))
      case .withdraw: return .send(.delegate(.withdrawRequested))
      case .legalLinkUnavailable, nil: return .none
      }

    case .presented(.alert(.cancelTapped)):
      state.destination = nil
      state.confirmation = nil
      return .none

    case .presented(.packDetail(.delegate(.backRequested))):
      state.destination = nil
      return .none

    case .presented(.packDetail(.delegate(.packDeleted))):
      state.destination = nil
      return .send(.async(.fetchPacks))

    case .presented(.packDetail(.delegate(.packChanged))):
      return .send(.async(.fetchPacks))

    case .presented(.packDetail):
      return .none

    case .dismiss:
      state.confirmation = nil
      return .none
    }
  }

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    return .none
  }

  /// 이미 같은 팝업이 떠 있으면 다시 띄우지 않는다.
  private func presentConfirmation(_ confirmation: Confirmation, state: inout State) {
    guard state.confirmation != confirmation else { return }
    state.confirmation = confirmation
    switch confirmation {
    case .logout: state.destination = .alert(.logout())
    case .withdraw: state.destination = .alert(.withdraw())
    case .legalLinkUnavailable: state.destination = .alert(.legalLinkUnavailable())
    }
  }

  private func openLegalURL(path: String, state: inout State) -> Effect<Action> {
    guard let legalBaseURL else {
      presentConfirmation(.legalLinkUnavailable, state: &state)
      return .none
    }
    return open(legalBaseURL.appending(path: path))
  }

  private func open(_ url: URL?) -> Effect<Action> {
    guard let url else { return .none }
    return .run { _ in
      await UIApplication.shared.open(url)
    }
  }
}
