//
//  SettingsHomeFeature.swift
//  Profile
//
//  Created by FestiCore on 11/12/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestiCoreStorageInterface
import FestivalDomainInterface
import Foundation
import ProfileInterface
import Web
import WebInterface

/// Figma S13-0 설정 홈. 마이 오른쪽 위 설정 버튼으로 열고 앱·계정·정보 설정 화면으로 이동한다.
@Reducer
public struct SettingsHomeFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 마이 화면이 `accountChanged`로 넘겨 주는 계정 상태
    public var profile: AuthProfile?
    public var hasSession: Bool
    public var isLoading: Bool
    public var message: String?
    /// 영속 저장소의 화면 모드 원시 값
    @SharedReader(.appearanceMode) public var storedAppearanceMode
    /// '화면 모드' 줄에 보이는 값
    public var appearanceMode: AppearanceMode {
      return AppearanceMode(storedValue: storedAppearanceMode)
    }

    /// 팝업과 설정 홈의 하위 목적지
    @Presents public var destination: Destination.State?

    /// 로그인하지 않았으면 계정 그룹을 숨긴다. 로그인은 마이의 로그인 카드에서 한다.
    public var showsAccount: Bool {
      return profile != nil || hasSession
    }

    public init(
      profile: AuthProfile? = nil,
      hasSession: Bool = false,
      isLoading: Bool = false,
      message: String? = nil
    ) {
      self.profile = profile
      self.hasSession = hasSession
      self.isLoading = isLoading
      self.message = message
    }
  }

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
    case account(AccountSettingsFeature)
    case appearance(AppearanceSettingsFeature)
    case legalDocument(WebFeature)
    case lockScreen(LockScreenSettingsFeature)
    case noticeList(NoticeListFeature)
    case notifications(NotificationSettingsFeature)
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
    /// 마이 화면이 계정 상태가 바뀔 때 보내는 입력
    case accountChanged(profile: AuthProfile?, hasSession: Bool, isLoading: Bool, message: String?)
    case backTapped
    case notificationsTapped
    case lockScreenTapped
    case appearanceTapped
    case accountTapped
    case noticeTapped
    case termsTapped
    case privacyTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {}

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {}

  // MARK: - DelegateAction

  /// 이동 계약은 ProfileInterface에 있다.
  public typealias DelegateAction = SettingsHomeDelegate

  @Dependency(\.festivalNotificationSettingsUseCase) private var notificationSettingsUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination(let destinationAction):
        return handleDestinationAction(
          state: &state,
          action: destinationAction
        )

      case .view(let viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case .async, .inner, .delegate:
        return .none
      }
    }
    .ifLet(
      \.$destination,
      action: \.destination
    )
  }
}

extension SettingsHomeFeature.Destination.State: Equatable {}
extension SettingsHomeFeature.Destination.Action: Equatable {}

extension SettingsHomeFeature {
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
      guard state.destination?.account != nil else { return .none }
      // 로그아웃되면 열려 있던 계정 화면과 확인 팝업을 닫는다.
      if lostSession {
        state.destination = nil
        return .none
      }
      return .send(.destination(.presented(.account(.view(.accountChanged(
        profile: profile,
        isLoading: isLoading,
        message: message
      ))))))

    case .backTapped:
      return .send(.delegate(.backRequested))

    case .notificationsTapped:
      state.destination = .notifications(.init())
      return .none

    case .lockScreenTapped:
      state.destination = .lockScreen(.init(hasSession: state.showsAccount))
      return .none

    case .appearanceTapped:
      state.destination = .appearance(.init())
      return .none

    case .accountTapped:
      guard state.showsAccount else { return .none }
      state.destination = .account(.init(
        profile: state.profile,
        isLoading: state.isLoading,
        message: state.message
      ))
      return .none

    case .noticeTapped:
      state.destination = .noticeList(.init())
      return .none

    case .termsTapped:
      return showLegalDocument(
        path: "terms",
        title: "이용약관",
        state: &state
      )

    case .privacyTapped:
      return showLegalDocument(
        path: "privacy",
        title: "개인정보 처리방침",
        state: &state
      )
    }
  }

  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.alert):
      state.destination = nil
      return .none

    case .presented(.account(.delegate(let delegateAction))):
      switch delegateAction {
      case .backRequested:
        state.destination = nil
        return .none
      case .logoutRequested:
        return .send(.delegate(.logoutRequested))
      case .withdrawRequested:
        return .send(.delegate(.withdrawRequested))
      case .refreshRequested:
        return .send(.delegate(.profileRefreshRequested))
      case .nicknameUpdated(let user):
        return .send(.delegate(.profileUpdated(user)))
      }

    case .presented(.appearance(.delegate(.backRequested))),
         .presented(.legalDocument(.delegate(.backToRoot))),
         .presented(.lockScreen(.delegate(.backRequested))),
         .presented(.noticeList(.delegate(.backRequested))):
      state.destination = nil
      return .none

    case .presented(.notifications(.delegate(.backRequested))):
      let flush = flushNotificationChanges(state)
      state.destination = nil
      return flush

    case .presented:
      return .none

    case .dismiss:
      // 뒤로 밀어 닫으면 자식 저장 효과가 취소되므로 남은 변경을 설정 홈 수명에서 보낸다.
      return flushNotificationChanges(state)
    }
  }

  /// 알림 설정 화면에 남은 변경을 화면과 상관없이 끝까지 보낸다.
  func flushNotificationChanges(_ state: State) -> Effect<Action> {
    guard case let .notifications(notifications) = state.destination,
          !notifications.unsavedChanges.isEmpty else { return .none }
    let changes = notifications.unsavedChanges
    return .run { _ in _ = try? await notificationSettingsUseCase.updateSettings(changes) }
  }

  private func showLegalDocument(
    path: String,
    title: String,
    state: inout State
  ) -> Effect<Action> {
    guard let legalBaseURL = LegalDocumentURL.baseURL else {
      // 이미 떠 있으면 다시 띄우지 않는다.
      if state.destination?.alert == nil { state.destination = .alert(.legalLinkUnavailable()) }
      return .none
    }
    state.destination = .legalDocument(.init(
      url: legalBaseURL.appending(path: path),
      title: title
    ))
    return .none
  }
}
