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
  public init() {}

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
    /// 팝업과 마이 화면의 하위 목적지
    @Presents public var destination: Destination.State?

    /// 로그인하지 않았으면 맨 위에 로그인 유도 카드를 보인다. 계정 상태를 확인하는 동안에는 숨긴다.
    public var showsLoginPrompt: Bool {
      return profile == nil && !hasSession && !isLoading
    }

    /// Figma More B: 로그아웃 상태에서는 기수 카드를 숨기고 로그인 카드만 둔다.
    public var showsBearerPrompt: Bool {
      return profile != nil || hasSession
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
    case packDetail(PackDetailFeature)
    case settings(SettingsHomeFeature)
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
    case socialLoginTapped(OAuthProvider)
    case bearerTapped
    case searchTapped
    case packTapped(String)
    case openPackDirections(festivalID: String, title: String)
    case settingsTapped
    /// 받은 팩이 없을 때 빈 카드의 '페스티벌 둘러보기'
    case browseFestivalsTapped
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
      guard let settings = state.destination?.settings else { return .none }
      // 계정 화면에서 로그아웃되면 설정 홈째로 닫고 마이로 돌아온다.
      if lostSession, settings.destination?.account != nil {
        state.destination = nil
        return .none
      }
      // 설정 홈이 열려 있으면 계정 줄과 계정 화면이 같은 값을 보이게 전달한다.
      return .send(.destination(.presented(.settings(.view(.accountChanged(
        profile: profile,
        hasSession: hasSession,
        isLoading: isLoading,
        message: message
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

    case let .socialLoginTapped(provider):
      return .send(.delegate(.socialLoginRequested(provider)))

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

    case .settingsTapped:
      state.destination = .settings(.init(
        profile: state.profile,
        hasSession: state.hasSession,
        isLoading: state.isLoading,
        message: state.message
      ))
      return .none

    case .browseFestivalsTapped:
      return .send(.delegate(.festivalListRequested))
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

    case .presented(.settings(.delegate(let delegateAction))):
      switch delegateAction {
      case .backRequested:
        state.destination = nil
        return .none
      case .logoutRequested:
        return .send(.delegate(.logoutRequested))
      case .withdrawRequested:
        return .send(.delegate(.withdrawRequested))
      case .profileRefreshRequested:
        return .send(.delegate(.profileRefreshRequested))
      case .profileUpdated(let user):
        return .send(.delegate(.profileUpdated(user)))
      }

    case .presented(.settings):
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
      // 설정 홈째로 닫히면 알림 설정의 저장 효과가 취소되므로 남은 변경을 마이 화면 수명에서 보낸다.
      guard case let .settings(settings) = state.destination else { return .none }
      return SettingsHomeFeature()
        .flushNotificationChanges(settings)
        .map { .destination(.presented(.settings($0))) }
    }
  }

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    return .none
  }
}
