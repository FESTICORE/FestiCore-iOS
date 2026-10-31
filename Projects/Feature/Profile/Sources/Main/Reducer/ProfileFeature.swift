//
//  ProfileFeature.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import Foundation
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
    public var isLogoutConfirmationPresented = false
    public var isWithdrawalConfirmationPresented = false
    public var isLegalLinkUnavailablePresented = false
    /// 확인 팝업을 띄울 때마다 바뀌는 값. 같은 팝업을 닫고 바로 다시 열어도 등장 애니메이션을 다시 재생한다.
    public var dialogPresentationID = 0

    public init() {}
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(Delegate)
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
    case logoutConfirmationDismissed
    case confirmLogoutTapped
    case withdrawTapped
    case withdrawalConfirmationDismissed
    case confirmWithdrawTapped
    case noticeTapped
    case termsTapped
    case privacyTapped
    case legalLinkUnavailableDismissed
  }

  @CasePathable
  public enum Delegate: Equatable {
    case bearerRequested
    case searchRequested
    case packRequested(String)
    case lockScreenRequested
    case loginRequested
    case profileRefreshRequested
    case logoutRequested
    case withdrawRequested
    case noticeRequested
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
        state.isLogoutConfirmationPresented = false
        state.isWithdrawalConfirmationPresented = false
        return .none
      case .view(.refreshTapped): return .send(.delegate(.profileRefreshRequested))
      case .view(.logoutTapped):
        state.isLogoutConfirmationPresented = true
        state.dialogPresentationID += 1
        return .none
      case .view(.logoutConfirmationDismissed):
        state.isLogoutConfirmationPresented = false
        return .none
      case .view(.confirmLogoutTapped):
        state.isLogoutConfirmationPresented = false
        return .send(.delegate(.logoutRequested))
      case .view(.withdrawTapped):
        state.isWithdrawalConfirmationPresented = true
        state.dialogPresentationID += 1
        return .none
      case .view(.withdrawalConfirmationDismissed):
        state.isWithdrawalConfirmationPresented = false
        return .none
      case .view(.confirmWithdrawTapped):
        state.isWithdrawalConfirmationPresented = false
        return .send(.delegate(.withdrawRequested))
      case .view(.noticeTapped): return .send(.delegate(.noticeRequested))
      case .view(.termsTapped):
        return openLegalURL(path: "terms", state: &state)
      case .view(.privacyTapped):
        return openLegalURL(path: "privacy", state: &state)
      case .view(.legalLinkUnavailableDismissed):
        state.isLegalLinkUnavailablePresented = false
        return .none
      case .delegate: return .none
      }
    }
  }

  private func openLegalURL(path: String, state: inout State) -> Effect<Action> {
    guard let legalBaseURL else {
      state.isLegalLinkUnavailablePresented = true
      state.dialogPresentationID += 1
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
