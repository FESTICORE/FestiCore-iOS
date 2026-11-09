//
//  ProfileFeature.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
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
    /// 새 버전이 있는 팩의 바뀐 공연 수(내 버전 기준). 읽지 못하면 비워 두고 버전만 보인다.
    public var packChangedSets: [String: Int] = [:]
    public var packLoad = PackLoad.idle
    /// 아직 연결되지 않은 이동은 누를 수 없게 둔다.
    public var isSearchAvailable = false
    /// 영속 저장소의 화면 모드 원시 값
    @SharedReader(.appearanceMode) public var storedAppearanceMode
    /// 설정의 '화면 모드' 줄에 보이는 값
    public var appearanceMode: AppearanceMode {
      return AppearanceMode(storedValue: storedAppearanceMode)
    }

    /// 팝업과 마이 화면의 하위 목적지
    @Presents public var destination: Destination.State?

    /// 로그인하지 않았으면 맨 위에 로그인 유도 카드를 보인다. 계정 상태를 확인하는 동안에는 숨긴다.
    public var showsLoginPrompt: Bool {
      return profile == nil && !hasSession && !isLoading
    }

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

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
    case account(AccountSettingsFeature)
    case appearance(AppearanceSettingsFeature)
    case legalDocument(WebFeature)
    case lockScreen(LockScreenSettingsFeature)
    case noticeList(NoticeListFeature)
    case notifications(NotificationSettingsFeature)
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
    case loginTapped
    case bearerTapped
    case searchTapped
    case packTapped(String)
    case openPackDirections(festivalID: String, title: String)
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
  public enum AsyncAction: Equatable {
    case fetchPacks
    case fetchPackChanges(
      festivalID: String,
      fromVersion: Int
    )
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case packsLoaded([FestivalReceivedPack])
    /// 서버 목록으로 새 버전 여부를 갱신한 결과
    case packsRefreshed([FestivalReceivedPack])
    case packsFailed
    case packChangesLoaded(
      festivalID: String,
      changedSets: Int?
    )
  }

  // MARK: - DelegateAction

  /// 이동 계약은 ProfileInterface에 있다.
  public typealias DelegateAction = ProfileDelegate

  @Dependency(\.festivalReceivedPackUseCase) private var receivedPackUseCase
  @Dependency(\.festivalPackDetailUseCase) private var packDetailUseCase
  @Dependency(\.festivalNotificationSettingsUseCase) private var notificationSettingsUseCase

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
      guard state.destination?.account != nil else { return .none }
      // 로그아웃되면 열려 있던 계정 화면과 확인 팝업을 닫는다.
      if lostSession {
        state.destination = nil
        return .none
      }
      return .send(.destination(.presented(.account(.view(.accountChanged(
        profile: profile, isLoading: isLoading, message: message
      ))))))

    case .onAppear:
      guard state.packLoad != .loading else { return .none }
      // 이미 보여 준 목록은 다시 읽는 동안 그대로 둔다.
      if state.packLoad != .loaded { state.packLoad = .loading }
      return .send(.async(.fetchPacks))

    case .packsRetryTapped:
      guard state.packLoad == .failed else { return .none }
      state.packLoad = .loading
      return .send(.async(.fetchPacks))

    case .loginTapped:
      return .send(.delegate(.loginRequested))

    case .bearerTapped:
      return .send(.delegate(.bearerRequested))

    case .searchTapped:
      return .send(.delegate(.searchRequested))

    case .packTapped(let id):
      guard let pack = state.packs.first(where: { $0.id == id }) else { return .none }
      state.destination = .packDetail(.init(festivalID: pack.id, title: pack.name))
      return .none

    case let .openPackDirections(
      festivalID,
      title
    ):
      state.destination = .packDetail(.init(
        festivalID: festivalID,
        title: title
      ))
      return .none

    case .notificationsTapped:
      state.destination = .notifications(.init())
      return .none

    case .lockScreenTapped:
      state.destination = .lockScreen(.init())
      return .none

    case .appearanceTapped:
      state.destination = .appearance(.init())
      return .none

    case .accountTapped:
      guard state.profile != nil || state.hasSession else {
        return .send(.delegate(.loginRequested))
      }
      state.destination = .account(.init(profile: state.profile, isLoading: state.isLoading, message: state.message))
      return .none

    case .noticeTapped:
      state.destination = .noticeList(.init())
      return .none

    case .termsTapped:
      return showLegalDocument(path: "terms", title: "이용약관", state: &state)

    case .privacyTapped:
      return showLegalDocument(path: "privacy", title: "개인정보 처리방침", state: &state)
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

    case let .fetchPackChanges(
      festivalID,
      fromVersion
    ):
      return .run { send in
        // 실패·오프라인이면 아무것도 보내지 않아 버전 표시를 그대로 둔다.
        guard let changes = try? await packDetailUseCase.packChanges(
          festivalID: festivalID,
          fromVersion: fromVersion
        ) else { return }
        await send(.inner(.packChangesLoaded(
          festivalID: festivalID,
          changedSets: changes.changedSets
        )))
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .packsLoaded(let packs):
      state.packs = packs
      state.packLoad = .loaded
      return .none

    case .packsRefreshed(let packs):
      state.packs = packs
      state.packLoad = .loaded
      // 새 버전이 있는 팩만 바뀐 공연 수를 묻는다(시안 More: "새 버전이 있어요 · 시간표 N개 변경").
      let updatable = packs.filter(\.hasUpdate)
      state.packChangedSets = state.packChangedSets.filter { entry in
        return updatable.contains { $0.id == entry.key }
      }
      return .merge(updatable.map { pack in
        return .send(.async(.fetchPackChanges(
          festivalID: pack.id,
          fromVersion: pack.packVersion
        )))
      })

    case let .packChangesLoaded(
      festivalID,
      changedSets
    ):
      state.packChangedSets[festivalID] = changedSets
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

    case .presented(.account):
      return .none

    case .presented(.appearance(.delegate(.backRequested))):
      state.destination = nil
      return .none

    case .presented(.appearance):
      return .none

    case .presented(.legalDocument(.delegate(.backToRoot))):
      state.destination = nil
      return .none

    case .presented(.legalDocument):
      return .none

    case .presented(.lockScreen(.delegate(.backRequested))):
      state.destination = nil
      return .none

    case .presented(.lockScreen):
      return .none

    case .presented(.noticeList(.delegate(.backRequested))):
      state.destination = nil
      return .none

    case .presented(.noticeList):
      return .none

    case .presented(.notifications(.delegate(.backRequested))):
      let flush = flushNotificationChanges(state)
      state.destination = nil
      return flush

    case .presented(.notifications):
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
      // 뒤로 밀어 닫으면 자식 저장 효과가 취소되므로 남은 변경을 마이 화면 수명에서 보낸다.
      return flushNotificationChanges(state)
    }
  }

  /// 알림 설정 화면에 남은 변경을 화면과 상관없이 끝까지 보낸다.
  private func flushNotificationChanges(_ state: State) -> Effect<Action> {
    guard case let .notifications(notifications) = state.destination,
          !notifications.unsavedChanges.isEmpty else { return .none }
    let changes = notifications.unsavedChanges
    return .run { _ in _ = try? await notificationSettingsUseCase.updateSettings(changes) }
  }

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    return .none
  }

  private func showLegalDocument(path: String, title: String, state: inout State) -> Effect<Action> {
    guard let legalBaseURL else {
      // 이미 떠 있으면 다시 띄우지 않는다.
      if state.destination?.alert == nil { state.destination = .alert(.legalLinkUnavailable()) }
      return .none
    }
    state.destination = .legalDocument(.init(url: legalBaseURL.appending(path: path), title: title))
    return .none
  }
}
