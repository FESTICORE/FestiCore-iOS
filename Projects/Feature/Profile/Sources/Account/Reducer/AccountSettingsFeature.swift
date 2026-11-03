//
//  AccountSettingsFeature.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import ProfileInterface

/// Figma S13 D 계정. 닉네임 변경, 로그인 수단, 계정 삭제, 로그아웃(E)을 다룬다.
@Reducer
public struct AccountSettingsFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var profile: AuthProfile?
    public var isLoading: Bool
    public var message: String?
    @Presents public var destination: Destination.State?
    /// 지금 띄운 확인 팝업이 무엇을 확인하는지
    public var confirmation: Confirmation?

    public init(profile: AuthProfile?, isLoading: Bool = false, message: String? = nil) {
      self.profile = profile
      self.isLoading = isLoading
      self.message = message
    }
  }

  public enum Confirmation: Equatable, Sendable {
    case logout
    case withdraw
  }

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
    case nickname(NicknameEditFeature)
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
    /// 마이 화면이 계정 상태가 바뀔 때 보내는 입력
    case accountChanged(profile: AuthProfile?, isLoading: Bool, message: String?)
    case backTapped
    case nicknameTapped
    case refreshTapped
    case withdrawTapped
    case logoutTapped
  }

  // MARK: - DelegateAction

  /// 이동 계약은 ProfileInterface에 있다.
  public typealias DelegateAction = AccountSettingsDelegate

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination(let destinationAction):
        return handleDestinationAction(state: &state, action: destinationAction)

      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension AccountSettingsFeature.Destination.State: Equatable {}
extension AccountSettingsFeature.Destination.Action: Equatable {}

extension AccountSettingsFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .accountChanged(profile, isLoading, message):
      state.profile = profile
      state.isLoading = isLoading
      state.message = message
      return .none

    case .backTapped:
      return .send(.delegate(.backRequested))

    case .nicknameTapped:
      guard let user = state.profile?.user, !state.isLoading else { return .none }
      state.destination = .nickname(.init(nickname: user.nickname ?? ""))
      return .none

    case .refreshTapped:
      return .send(.delegate(.refreshRequested))

    case .withdrawTapped:
      presentConfirmation(.withdraw, state: &state)
      return .none

    case .logoutTapped:
      presentConfirmation(.logout, state: &state)
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
      case nil: return .none
      }

    case .presented(.alert(.cancelTapped)):
      state.destination = nil
      state.confirmation = nil
      return .none

    case .presented(.nickname(.delegate(.saved(let user)))):
      state.destination = nil
      if let profile = state.profile {
        state.profile = AuthProfile(user: user, currentTermsVersion: profile.currentTermsVersion)
      }
      return .send(.delegate(.nicknameUpdated(user)))

    case .presented(.nickname):
      return .none

    case .dismiss:
      state.confirmation = nil
      return .none
    }
  }

  /// 처리 중이거나 같은 팝업이 떠 있으면 다시 띄우지 않는다.
  private func presentConfirmation(_ confirmation: Confirmation, state: inout State) {
    guard !state.isLoading, state.confirmation != confirmation else { return }
    state.confirmation = confirmation
    switch confirmation {
    case .logout: state.destination = .alert(.logout())
    case .withdraw: state.destination = .alert(.withdraw())
    }
  }
}
