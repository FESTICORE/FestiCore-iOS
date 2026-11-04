//
//  MainTabCoordinator.swift
//  FestiCore
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import FestivalDomainInterface
import FestiCoreDesignKit
import Foundation

@Reducer
struct MainTabCoordinator {
  typealias Tab = FCTabBar.Tab
  @Dependency(\.festivalBookedStore) private var bookedStore
  private let legalBaseURL: URL?

  init(legalBaseURL: URL? = AppCoordinatorView.legalBaseURL(
    host: Bundle.main.object(forInfoDictionaryKey: "FestiCoreAPIHost") as? String
  )) {
    self.legalBaseURL = legalBaseURL
  }

  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab
    var previousTab: Tab = .live
    var festivalState: FestivalCoordinator.State
    var timetableCoordinatorState = TimetableCoordinator.State()
    var timetableState: TimetableFeature.State {
      get { timetableCoordinatorState.timetableState }
      set { timetableCoordinatorState.timetableState = newValue }
    }
    var flagState = FestivalFlagFeature.State()
    var profileState = ProfileFeature.State()
    var loginState = LoginFeature.State()
    var authFlow = AppCoordinator.AuthFlow()

    /// 모달이 열려도 기존 탭바 공간은 유지해 뒤 화면이 이동하지 않게 한다.
    var shouldReserveTabBarSpace: Bool {
      if selectedTab == .timetable, timetableState.destination?.schedulePick != nil {
        return false
      }
      if selectedTab == .my, profileState.hidesTabBarForProfileRoute {
        return false
      }
      return selectedTab != .live || (festivalState.routes.count != 1 && !isNotificationInboxOnTop)
    }

    var isNotificationInboxOnTop: Bool {
      return festivalState.routes.last?.screen.is(\.notificationInbox) == true
    }

    var shouldHideTabBar: Bool {
      if authFlow.presentation != nil { return true }
      switch selectedTab {
      case .live:
        return festivalState.routes.count == 1 || isNotificationInboxOnTop
          || festivalState.routes.last?.screen.liveBoard?.alert != nil
      case .timetable:
        return timetableState.destination?.schedulePick != nil || timetableState.setDetail != nil
      case .my:
        // 마이의 설정·정보 화면은 탭바 없이 표시한다.
        return profileState.destination?.alert != nil
          || profileState.hidesTabBarForProfileRoute
          || profileState.destination?.account?.destination != nil
          || profileState.destination?.packDetail?.destination != nil
      case .flag:
        return false
      }
    }

    init(selectedTab: Tab = .live) {
      self.selectedTab = selectedTab
      festivalState = .init()
    }
  }

  @CasePathable
  enum Action {
    case tabTapped(Tab)
    case selectTab(Tab)
    case tabReselected(Tab)
    case openWidgetRoute(WidgetDeepLink)
    case festival(FestivalCoordinator.Action)
    case timetable(TimetableFeature.Action)
    case timetableCoordinator(TimetableCoordinator.Action)
    case flag(FestivalFlagFeature.Action)
    case profileCoordinator(ProfileCoordinator.Action)
    case login(LoginFeature.Action)
    case signUp(SignUpFlowCoordinator.Action)
    case authInputsChanged(previous: AuthInputs?, current: AuthInputs)
    case delegate(Delegate)
    case completePendingBookmark(id: String, userID: String, shouldBeBooked: Bool)
  }

  enum Delegate {
    case myProfileUpdated(AuthUser)
    case myLoginRequested
    case myCrewLoginRequested
    case myFollowLoginRequested
    case myLogoutRequested
    case myWithdrawRequested
    case myProfileRefreshRequested
    case dismissAuthFlow
    case retryProfile
    case resolveMigration(Bool)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.festivalState, action: \.festival) {
      FestivalCoordinator()
    }
    Scope(
      state: \.timetableCoordinatorState,
      action: \.timetableCoordinator
    ) {
      TimetableCoordinator()
    }
    Scope(state: \.flagState, action: \.flag) {
      FestivalFlagFeature()
    }
    Scope(
      state: \.profileState,
      action: \.profileCoordinator
    ) {
      ProfileCoordinator(legalBaseURL: legalBaseURL)
    }
    Scope(state: \.loginState, action: \.login) {
      LoginFeature()
    }
    Scope(
      state: \.authFlow.signUpFlow,
      action: \.signUp
    ) {
      SignUpFlowCoordinator()
    }

    Reduce { state, action in
      switch action {
      case let .tabTapped(tab):
        return .send(tab == state.selectedTab ? .tabReselected(tab) : .selectTab(tab))

      case let .selectTab(tab):
        if tab != state.selectedTab {
          state.previousTab = state.selectedTab
        }
        state.selectedTab = tab
        switch tab {
        case .timetable:
          return syncTimetable(state: &state, appearing: true)
        case .flag:
          return syncFlag(state: &state)
        case .live:
          return .send(.festival(.reloadCachedPacks))
        case .my:
          return .none
        }

      case let .tabReselected(tab):
        _ = tab
        return .none

      case let .openWidgetRoute(route):
        if state.selectedTab != .live { state.previousTab = state.selectedTab }
        state.selectedTab = .live
        switch route {
        case .festivalList:
          return .send(.festival(.showFestivalList))
        case let .festival(id):
          return .send(.festival(.openWidgetFestival(id)))
        }

      case .festival(.delegate(.loginRequested)):
        return .send(.delegate(.myLoginRequested))

      case .festival(.delegate(.flagTabRequested)):
        return .send(.selectTab(.flag))

      case .festival(.delegate(.crewLoginRequested)):
        return .send(.delegate(.myCrewLoginRequested))

      case .festival(.delegate(.followLoginRequested)):
        return .send(.delegate(.myFollowLoginRequested))

      case .festival(.delegate(.flagDirectoryRequested)):
        return .send(.selectTab(.flag))

      case let .festival(.delegate(.packDirectionsRequested(
        festivalID,
        title
      ))):
        return .concatenate(
          .send(.selectTab(.my)),
          .send(.profileCoordinator(.profile(.view(.openPackDirections(
            festivalID: festivalID,
            title: title
          )))))
        )

      case .festival:
        switch state.selectedTab {
        case .timetable: return syncTimetable(state: &state, appearing: false)
        case .flag: return syncFlag(state: &state)
        case .live, .my: return .none
        }

      case let .timetableCoordinator(.delegate(.scheduleSaved(
        id,
        ids
      ))):
        return .send(.festival(.myScheduleSaved(festivalID: id, setIDs: ids)))

      case let .timetable(action):
        return .send(.timetableCoordinator(.timetable(action)))

      case .timetableCoordinator:
        return .none

      case .flag(.directory(.delegate(.loginRequested))):
        return .send(.delegate(.myLoginRequested))

      case .flag(.directory(.delegate(.termsAcceptanceRequested))):
        return .send(.delegate(.myProfileRefreshRequested))

      case .flag, .delegate:
        return .none

      case let .authInputsChanged(
        previous,
        current
      ):
        return synchronizeAuthInputs(
          previous: previous,
          current: current
        )

      case .profileCoordinator(.profile(.delegate(.loginRequested))):
        return .send(.delegate(.myLoginRequested))
      case .profileCoordinator(.profile(.delegate(.profileRefreshRequested))):
        return .send(.delegate(.myProfileRefreshRequested))
      case .profileCoordinator(.profile(.delegate(.logoutRequested))):
        return .send(.delegate(.myLogoutRequested))
      case .profileCoordinator(.profile(.delegate(.withdrawRequested))):
        return .send(.delegate(.myWithdrawRequested))
      case let .profileCoordinator(.profile(.delegate(.profileUpdated(user)))):
        return .send(.delegate(.myProfileUpdated(user)))
      case .profileCoordinator(.profile(.destination(.presented(.packDetail(.delegate(.packDeleted)))))),
           .profileCoordinator(.profile(.destination(.presented(.packDetail(.delegate(.packChanged)))))):
        return .send(.festival(.reloadCachedPacks))
      case .profileCoordinator:
        return .none

      case .login, .signUp:
        return .none

      case let .completePendingBookmark(id, userID, shouldBeBooked):
        guard state.authFlow.verifiedUserID == userID,
              (state.authFlow.profile?.isEligible == true
                || (state.authFlow.profile == nil && bookedStore.offlineEligible(userID))) else { return .none }
        bookedStore.setBookmark(id, booked: shouldBeBooked, for: userID)
        return .run { send in
          await send(.festival(.reloadBookmarks(userID: userID)))
          await send(.festival(.bookmarkSaved(
            id: id,
            booked: shouldBeBooked
          )))
        }
      }
    }
  }

  /// 계정 입력의 소유자인 홈에서 각 기능에 필요한 변경만 순서대로 전달한다.
  private func synchronizeAuthInputs(
    previous: AuthInputs?,
    current: AuthInputs
  ) -> Effect<Action> {
    guard previous != current else { return .none }
    return .run { send in
      if previous?.login != current.login, let login = current.login {
        await send(.login(.view(.contextChanged(
          login.context,
          flowMessage: login.message
        ))))
      }

      if previous?.signUp != current.signUp {
        if let signUp = current.signUp {
          await send(.signUp(.view(.flowChanged(
            isSubmitting: signUp.isSubmitting,
            message: signUp.message,
            termsUpdateExhausted: signUp.termsUpdateExhausted,
            legalBaseURL: legalBaseURL
          ))))
        } else if previous?.signUp != nil {
          await send(.signUp(.view(.sheetClosed)))
        }
      }

      if previous?.account != current.account {
        let account = current.account
        await send(.profileCoordinator(.profile(.view(.accountChanged(
          profile: account.profile,
          hasSession: account.hasSession,
          isLoading: account.isLoading,
          message: account.message
        )))))
      }

      let oldSession = previous?.session ?? .init(
        hasSession: false,
        userID: nil
      )
      let session = current.session
      if oldSession != session {
        let accountChanged = oldSession.userID != nil && oldSession.userID != session.userID
        let refreshAccountData = (!oldSession.hasSession && session.hasSession)
          || accountChanged || (oldSession.hasSession && !session.hasSession)
        if refreshAccountData {
          await send(.flag(.accountChanged))
        }
        if accountChanged || (oldSession.hasSession && !session.hasSession) {
          await send(.timetable(.view(.accountChanged)))
        }
        await send(.festival(.sessionChanged(
          hasSession: session.hasSession,
          userID: session.userID
        )))
      }
    }
  }

  private func syncFlag(state: inout State) -> Effect<Action> {
    let selectedID: String?
    let pack: FestivalPackDocument?
    // 기수 보드는 라이브 보드 위에 덮이는 화면이라 그 아래 축제를 기준으로 삼는다.
    if let screen = state.festivalState.routes.last(where: {
      !$0.screen.is(\.bearerBoard) && !$0.screen.is(\.notificationInbox)
    })?.screen {
      switch screen {
      case let .festivalList(festival):
        selectedID = festival.selectedFestivalID
        pack = festival.displayDocument
      case let .liveBoard(festival):
        selectedID = festival.selectedFestivalID
        pack = festival.displayDocument
      case .bearerBoard, .notificationInbox:
        selectedID = nil
        pack = nil
      }
    } else {
      selectedID = nil
      pack = nil
    }
    // 깃발 카드의 구역 칩은 선택 축제 팩의 구역 이름을 쓴다. 다른 축제의 팩이면 비운다.
    let zones = pack?.id == selectedID ? pack?.zones ?? [] : []
    let zoneNames = Dictionary(zones.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    if state.flagState.directory.zoneNames != zoneNames {
      state.flagState.directory.zoneNames = zoneNames
    }
    return selectedID == state.flagState.festivalID
      ? .none : .send(.flag(.festivalChanged(selectedID)))
  }

  /// 라이브 보드에서 고른 축제의 팩을 타임테이블에 옮긴다.
  /// 고른 축제가 없으면 이전 축제의 시간표가 남지 않게 비운다.
  private func syncTimetable(
    state: inout State,
    appearing: Bool
  ) -> Effect<Action> {
    var selected: (festivalID: String?, pack: FestivalPackDocument, source: String, imageURL: (String?) -> URL?)?
    if let screen = state.festivalState.routes.last(where: {
      !$0.screen.is(\.bearerBoard) && !$0.screen.is(\.notificationInbox)
    })?.screen,
       case let .liveBoard(home) = screen,
       let pack = home.displayDocument {
      selected = (
        home.selectedFestivalID,
        pack,
        home.onlineDetail == nil ? "저장된 축제 팩" : "온라인 축제 정보",
        home.imageURL(for:)
      )
    }
    let days = selected.map { FestivalPackTimetableMapper.days(from: $0.pack, imageURL: $0.imageURL) } ?? []
    let daysChanged = state.timetableState.days != days
    if daysChanged {
      let selectedID = state.timetableState.selectedDay?.id
      state.timetableState.days = days
      state.timetableState.selectedDayIndex = days.firstIndex { $0.id == selectedID } ?? 0
      state.timetableState.source = selected?.source ?? ""
    }

    let festivalID = selected?.festivalID
    if festivalID != state.timetableState.festivalID {
      return .send(.timetable(.view(.festivalChanged(festivalID))))
    }
    guard daysChanged || appearing else { return .none }
    return .run { send in
      if daysChanged {
        await send(.timetable(.view(.packUpdated)))
      }
      if appearing {
        await send(.timetable(.view(.timetableAppeared)))
      }
    }
  }
}
