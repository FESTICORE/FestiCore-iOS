//
//  ProfileFeature.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

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
    case delegate(ProfileDelegate)
  }

  @CasePathable
  public enum View: Equatable {
    case bearerTapped
    case searchTapped
    case packTapped(String)
    case notificationsTapped
    case lockScreenTapped
    case accountTapped(isSignedIn: Bool)
    case accountDismissed
    case refreshTapped
    case logoutTapped
    case withdrawTapped
    case noticeTapped
    case termsTapped
    case privacyTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.bearerTapped): return .send(.delegate(.bearerRequested))
      case .view(.searchTapped): return .send(.delegate(.searchRequested))
      case let .view(.packTapped(id)): return .send(.delegate(.packRequested(id)))
      case .view(.notificationsTapped):
        return open(URL(string: UIApplication.openSettingsURLString))
      case .view(.lockScreenTapped): return .send(.delegate(.lockScreenRequested))
      case let .view(.accountTapped(isSignedIn)):
        if isSignedIn {
          state.isAccountPresented = true
          return .none
        }
        return .send(.delegate(.loginRequested))
      case .view(.accountDismissed):
        state.isAccountPresented = false
        if state.confirmation == .logout || state.confirmation == .withdraw {
          state.destination = nil
          state.confirmation = nil
        }
        return .none
      case .view(.refreshTapped): return .send(.delegate(.profileRefreshRequested))
      case .view(.logoutTapped):
        presentConfirmation(.logout, state: &state)
        return .none
      case .view(.withdrawTapped):
        presentConfirmation(.withdraw, state: &state)
        return .none
      case .view(.noticeTapped): return .send(.delegate(.noticeRequested))
      case .view(.termsTapped):
        return openLegalURL(path: "terms", state: &state)
      case .view(.privacyTapped):
        return openLegalURL(path: "privacy", state: &state)
      case .destination(.presented(.alert(.confirmTapped))):
        let confirmation = state.confirmation
        state.destination = nil
        state.confirmation = nil
        switch confirmation {
        case .logout: return .send(.delegate(.logoutRequested))
        case .withdraw: return .send(.delegate(.withdrawRequested))
        case .legalLinkUnavailable, nil: return .none
        }
      case .destination(.presented(.alert(.cancelTapped))):
        state.destination = nil
        state.confirmation = nil
        return .none
      case .destination(.dismiss):
        state.confirmation = nil
        return .none
      case .delegate: return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
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

extension ProfileFeature.Destination.State: Equatable {}
extension ProfileFeature.Destination.Action: Equatable {}
