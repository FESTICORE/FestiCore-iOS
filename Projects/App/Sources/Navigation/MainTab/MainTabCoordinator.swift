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
  @Dependency(\.festivalLibraryUseCase) private var festivalLibraryUseCase
  @ObservableState
  struct State: Equatable {
    struct Tabs: Equatable {
      var festival = FestivalCoordinator.State()
      var timetable = TimetableCoordinator.State()
      var flag = FestivalFlagFeature.State()
      var profile = ProfileFeature.State()

      var timetableFeature: TimetableFeature.State {
        get { timetable.timetableState }
        set { timetable.timetableState = newValue }
      }
    }

    var selectedTab: Tab
    var previousTab: Tab = .live
    var tabs = Tabs()
    var loginState = LoginFeature.State()
    var authFlow = AppCoordinator.AuthFlow()

    /// 모달이 열려도 기존 탭바 공간은 유지해 뒤 화면이 이동하지 않게 한다.
    var shouldReserveTabBarSpace: Bool {
      switch selectedTab {
      case .live:
        return !isCrewCreatePresented
          && tabs.festival.routes.count != 1
          && !isNotificationInboxOnTop
      case .timetable:
        return tabs.timetableFeature.destination?.schedulePick == nil
      case .my:
        return !tabs.profile.hidesTabBarForProfileRoute
      case .flag:
        return true
      }
    }

    var isNotificationInboxOnTop: Bool {
      return tabs.festival.routes.last?.screen.is(\.notificationInbox) == true
    }

    private var isCrewCreatePresented: Bool {
      return tabs.festival.routes.contains { route in
        switch route.screen {
        case let .festivalList(festival): return festival.crewCreate != nil
        case let .liveBoard(festival): return festival.crewCreate != nil
        case .bearerBoard, .notificationInbox: return false
        }
      }
    }

    private var isFestivalSwitcherPresented: Bool {
      return tabs.festival.routes.contains { route in
        switch route.screen {
        case let .festivalList(festival), let .liveBoard(festival):
          return festival.festivalSwitcher != nil
        case .bearerBoard, .notificationInbox:
          return false
        }
      }
    }

    var shouldHideTabBar: Bool {
      if authFlow.presentation != nil { return true }
      switch selectedTab {
      case .live:
        return isCrewCreatePresented
          || isFestivalSwitcherPresented
          || tabs.festival.routes.count == 1
          || isNotificationInboxOnTop
          || tabs.festival.routes.last?.screen.liveBoard?.alert != nil
      case .timetable:
        return tabs.timetableFeature.destination?.schedulePick != nil
          || tabs.timetableFeature.setDetail != nil
      case .my:
        // 마이의 설정·정보 화면은 탭바 없이 표시한다.
        return tabs.profile.destination?.alert != nil
          || tabs.profile.hidesTabBarForProfileRoute
          || tabs.profile.destination?.account?.destination != nil
          || tabs.profile.destination?.packDetail?.alert != nil
      case .flag:
        return false
      }
    }

    init(selectedTab: Tab = .live) {
      self.selectedTab = selectedTab
    }
  }

  @CasePathable
  enum Action {
    case tabTapped(Tab)
    case selectTab(Tab)
    case tabReselected(Tab)
    case openWidgetRoute(WidgetDeepLink)
    case scopeAction(ScopeAction)
    case authInputsChanged(previous: AuthInputs?, current: AuthInputs)
    case delegate(Delegate)
    case completePendingBookmark(id: String, userID: String, shouldBeBooked: Bool)

  }

  @CasePathable
  enum ScopeAction {
    case festival(FestivalCoordinator.Action)
    case timetable(TimetableFeature.Action)
    case timetableCoordinator(TimetableCoordinator.Action)
    case flag(FestivalFlagFeature.Action)
    case profileCoordinator(ProfileCoordinator.Action)
    case login(LoginFeature.Action)
    case signUp(SignUpFlowCoordinator.Action)
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
    Scope(
      \.tabs.festival,
      action: \.scopeAction.festival
    ) {
      FestivalCoordinator()
    }
    Scope(
      \.tabs.timetable,
      action: \.scopeAction.timetableCoordinator
    ) {
      TimetableCoordinator()
    }
    Scope(
      \.tabs.flag,
      action: \.scopeAction.flag
    ) {
      FestivalFlagFeature()
    }
    Scope(
      \.tabs.profile,
      action: \.scopeAction.profileCoordinator
    ) {
      ProfileCoordinator()
    }
    Scope(
      \.loginState,
      action: \.scopeAction.login
    ) {
      LoginFeature()
    }
    Scope(
      \.authFlow.signUpFlow,
      action: \.scopeAction.signUp
    ) {
      SignUpFlowCoordinator()
    }

    Reduce { state, action in
      switch action {
      case .tabTapped, .selectTab, .tabReselected:
        return handleTabAction(
          state: &state,
          action: action
        )

      case let .openWidgetRoute(route):
        if state.selectedTab != .live { state.previousTab = state.selectedTab }
        state.selectedTab = .live
        switch route {
        case .festivalList:
          return .send(.scopeAction(.festival(.showFestivalList)))
        case let .festival(id):
          return .send(.scopeAction(.festival(.openWidgetFestival(id))))
        }

      case let .scopeAction(action):
        return handleScopeAction(
          state: &state,
          action: action
        )

      case .delegate:
        return .none

      case let .authInputsChanged(
        previous,
        current):
        return synchronizeAuthInputs(
          previous: previous,
          current: current
        )

      case let .completePendingBookmark(
        id,
        userID,
        shouldBeBooked):
        guard state.authFlow.verifiedUserID == userID,
              (state.authFlow.profile?.isEligible == true
                || (state.authFlow.profile == nil && festivalLibraryUseCase.isOfflineBookingEligible(userID: userID))) else { return .none }
        festivalLibraryUseCase.setBooked(
          shouldBeBooked,
          festivalID: id,
          for: userID
        )
        return .run { send in
          await send(.scopeAction(.festival(.reloadBookmarks(userID: userID))))
          await send(.scopeAction(.festival(.bookmarkSaved(
            id: id,
            booked: shouldBeBooked
          ))))
        }
      }
    }
  }

}

extension MainTabCoordinator {
  private func handleScopeAction(
    state: inout State,
    action: ScopeAction
  ) -> Effect<Action> {
    switch action {
    case .festival(.delegate(.loginRequested)):
      return .send(.delegate(.myLoginRequested))

    case .festival(.delegate(.flagTabRequested)),
         .festival(.delegate(.flagDirectoryRequested)):
      return .send(.selectTab(.flag))

    case .festival(.delegate(.crewLoginRequested)):
      return .send(.delegate(.myCrewLoginRequested))

    case .festival(.delegate(.followLoginRequested)):
      return .send(.delegate(.myFollowLoginRequested))

    case let .festival(.delegate(.packDirectionsRequested(
      festivalID,
      title))):
      return .run { send in
        await send(.selectTab(.my))
        await send(.scopeAction(.profileCoordinator(.profile(.view(.openPackDirections(
          festivalID: festivalID,
          title: title
        ))))))
      }

    case .festival:
      switch state.selectedTab {
      case .timetable:
        return syncTimetable(
          state: &state,
          appearing: false
        )
      case .flag:
        return syncFlag(state: &state)
      case .live, .my:
        return .none
      }

    case let .timetableCoordinator(.delegate(.scheduleSaved(
      id,
      ids))):
      return .send(.scopeAction(.festival(.myScheduleSaved(
        festivalID: id,
        setIDs: ids
      ))))

    case let .timetable(action):
      return .send(.scopeAction(.timetableCoordinator(.timetable(action))))

    case .timetableCoordinator:
      return .none

    case .flag(.directory(.delegate(.loginRequested))):
      return .send(.delegate(.myLoginRequested))

    case .flag(.directory(.delegate(.termsAcceptanceRequested))):
      return .send(.delegate(.myProfileRefreshRequested))

    case .flag:
      return .none

    case let .profileCoordinator(action):
      return handleProfileCoordinatorAction(action)

    case .login, .signUp:
      return .none
    }
  }

  private func handleTabAction(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
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
        return syncTimetable(
          state: &state,
          appearing: true
        )
      case .flag:
        return syncFlag(state: &state)
      case .live:
        return .send(.scopeAction(.festival(.reloadCachedPacks)))
      case .my:
        return .none
      }

    case .tabReselected:
      return .none

    default:
      return .none
    }
  }

  private func handleProfileCoordinatorAction(
    _ action: ProfileCoordinator.Action
  ) -> Effect<Action> {
    switch action {
    case .profile(.delegate(.loginRequested)):
      return .send(.delegate(.myLoginRequested))

    case .profile(.delegate(.profileRefreshRequested)):
      return .send(.delegate(.myProfileRefreshRequested))

    case .profile(.delegate(.logoutRequested)):
      return .send(.delegate(.myLogoutRequested))

    case .profile(.delegate(.withdrawRequested)):
      return .send(.delegate(.myWithdrawRequested))

    case let .profile(.delegate(.profileUpdated(user))):
      return .send(.delegate(.myProfileUpdated(user)))

    case .profile(.destination(.presented(.packDetail(.delegate(.packDeleted))))),
         .profile(.destination(.presented(.packDetail(.delegate(.packChanged))))):
      return .send(.scopeAction(.festival(.reloadCachedPacks)))

    default:
      return .none
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
        await send(.scopeAction(.login(.view(.contextChanged(
          login.context,
          flowMessage: login.message
        )))))
      }

      if previous?.signUp != current.signUp {
        if let signUp = current.signUp {
          await send(.scopeAction(.signUp(.view(.flowChanged(
            isSubmitting: signUp.isSubmitting,
            message: signUp.message,
            termsUpdateExhausted: signUp.termsUpdateExhausted
          )))))
        } else if previous?.signUp != nil {
          await send(.scopeAction(.signUp(.view(.sheetClosed))))
        }
      }

      if previous?.account != current.account {
        let account = current.account
        await send(.scopeAction(.profileCoordinator(.profile(.view(.accountChanged(
          profile: account.profile,
          hasSession: account.hasSession,
          isLoading: account.isLoading,
          message: account.message
        ))))))
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
          await send(.scopeAction(.flag(.accountChanged)))
        }
        if accountChanged || (oldSession.hasSession && !session.hasSession) {
          await send(.scopeAction(.timetable(.view(.accountChanged))))
        }
        await send(.scopeAction(.festival(.sessionChanged(
          hasSession: session.hasSession,
          userID: session.userID
        ))))
      }
    }
  }

  private func syncFlag(state: inout State) -> Effect<Action> {
    let selectedID: String?
    let pack: FestivalPackDocument?
    // 기수 보드는 라이브 보드 위에 덮이는 화면이라 그 아래 축제를 기준으로 삼는다.
    if let screen = state.tabs.festival.routes.last(where: {
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
    let zoneNames = Dictionary(
      zones.map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first })
    if state.tabs.flag.directory.zoneNames != zoneNames {
      state.tabs.flag.directory.zoneNames = zoneNames
    }
    return selectedID == state.tabs.flag.festivalID
    ? .none : .send(.scopeAction(.flag(.festivalChanged(selectedID))))
  }

  /// 라이브 보드에서 고른 축제의 팩을 타임테이블에 옮긴다.
  /// 고른 축제가 없으면 이전 축제의 시간표가 남지 않게 비운다.
  private func syncTimetable(
    state: inout State,
    appearing: Bool
  ) -> Effect<Action> {
    var selected: (festivalID: String?, pack: FestivalPackDocument, source: String, imageURL: (String?) -> URL?)?
    if let screen = state.tabs.festival.routes.last(where: {
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
    let days = selected.map { FestivalPackTimetableMapper.days(
      from: $0.pack,
      imageURL: $0.imageURL) } ?? []
    let daysChanged = state.tabs.timetableFeature.days != days
    if daysChanged {
      let selectedID = state.tabs.timetableFeature.selectedDay?.id
      state.tabs.timetableFeature.days = days
      state.tabs.timetableFeature.selectedDayIndex = days.firstIndex { $0.id == selectedID } ?? 0
      state.tabs.timetableFeature.source = selected?.source ?? ""
    }

    let festivalID = selected?.festivalID
    if festivalID != state.tabs.timetableFeature.festivalID {
      return .send(.scopeAction(.timetable(.view(.festivalChanged(festivalID)))))
    }
    guard daysChanged || appearing else { return .none }
    return .run { send in
      if daysChanged {
        await send(.scopeAction(.timetable(.view(.packUpdated))))
      }
      if appearing {
        await send(.scopeAction(.timetable(.view(.timetableAppeared))))
      }
    }
  }
}
