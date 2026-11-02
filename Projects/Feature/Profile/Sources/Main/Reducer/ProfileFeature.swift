//
//  ProfileFeature.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import ProfileInterface
import UIKit

/// 화면에 실제로 전달된 팩만 표시한다. 데이터가 없으면 빈 목록으로 남는다.
public struct ProfileReceivedPack: Equatable, Identifiable {
  public let id: String
  public let name: String
  public let detail: String
  public let imageName: String?
  public let hasUpdate: Bool

  public init(id: String, name: String, detail: String, imageName: String? = nil, hasUpdate: Bool = false) {
    self.id = id
    self.name = name
    self.detail = detail
    self.imageName = imageName
    self.hasUpdate = hasUpdate
  }
}

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
    public var packs: [ProfileReceivedPack] = []
    /// 아직 연결되지 않은 이동은 누를 수 없게 둔다.
    public var isBearerNavigationAvailable = false
    public var isSearchAvailable = false
    public var isPackNavigationAvailable = false
    public var isLockScreenAvailable = false
    public var isNoticeAvailable = false

    public var isAccountPresented = false
    /// 로그아웃·회원 탈퇴·문서 안내 확인 팝업. 계정 시트 위에 `fcAlert`로 띄운다.
    @Presents public var destination: Destination.State?
    /// 지금 띄운 확인 팝업이 무엇을 확인하는지
    public var confirmation: Confirmation?

    public init() {}
  }

  public enum Confirmation: Equatable, Sendable {
    case logout
    case withdraw
    case legalLinkUnavailable
  }

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case destination(PresentationAction<Destination.Action>)
    case view(View)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    /// 앱 코디네이터가 계정 상태가 바뀔 때 보내는 입력
    case accountChanged(profile: AuthProfile?, hasSession: Bool, isLoading: Bool, message: String?)
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

  // MARK: - DelegateAction

  /// 이동 계약은 ProfileInterface에 있다.
  public typealias DelegateAction = ProfileDelegate

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination(let destinationAction):
        return handleDestinationAction(state: &state, action: destinationAction)

      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

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

    case .bearerTapped:
      return .send(.delegate(.bearerRequested))

    case .searchTapped:
      return .send(.delegate(.searchRequested))

    case .packTapped(let id):
      return .send(.delegate(.packRequested(id)))

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
