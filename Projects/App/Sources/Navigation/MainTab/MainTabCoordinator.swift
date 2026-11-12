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
import FestiCoreUtility

@Reducer
struct MainTabCoordinator {
  typealias Tab = FCTabBar.Tab
  @Dependency(\.festivalBookedStore) private var bookedStore
  @Dependency(\.date.now) var now

  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab
    var previousTab: Tab = .live
    var festivalState: FestivalCoordinator.State
    var timetableCoordinatorState = TimetableCoordinator.State()
    var timetableState: TimetableFeature.State {
      get { return timetableCoordinatorState.timetableState }
      set { timetableCoordinatorState.timetableState = newValue }
    }
    var flagCoordinatorState = FlagCoordinator.State()
    /// 깃발 탭 루트의 디렉토리. 축제·계정 동기화가 읽고 쓴다.
    var flagState: FestivalFlagFeature.State {
      get { return flagCoordinatorState.directory }
      set { flagCoordinatorState.directory = newValue }
    }
    var profileState = ProfileFeature.State()
    var authFlow = AuthFlowState()
    /// 마이 '기수이신가요?'로 여는 기수 등록 흐름(전체 화면)
    @Presents var bearerEntry: BearerEntryCoordinator.State?

    /// 기수 코드를 넣을 페스티벌. 라이브 탭에서 연 페스티벌, 없으면 받은 팩이 하나일 때 그 팩이다.
    var bearerFestivalID: String? {
      if let festivalID = festivalState.routes
        .last(where: { $0.screen.is(\.liveBoard) })?
        .screen.liveBoard?.selectedFestivalID {
        return festivalID
      }
      return profileState.packs.count == 1 ? profileState.packs.first?.id : nil
    }

    /// 모달이 열려도 기존 탭바 공간은 유지해 뒤 화면이 이동하지 않게 한다.
    var shouldReserveTabBarSpace: Bool {
      if selectedTab == .timetable,
         timetableState.destination?.schedulePick != nil || timetableCoordinatorState.setList != nil {
        return false
      }
      if selectedTab == .my, profileState.hidesTabBarForProfileRoute {
        return false
      }
      return selectedTab != .live
        || (festivalState.routes.count != 1 && !isNotificationInboxOnTop && !isCrewOnTop)
    }

    var isNotificationInboxOnTop: Bool {
      return festivalState.routes.last?.screen.is(\.notificationInbox) == true
    }

    /// 크루(S07)·참여 확인(S08)·크루 만들기·준비 안내(S15)는 아래 고정 영역이 있어 탭바 없이 표시한다.
    var isCrewOnTop: Bool {
      guard let screen = festivalState.routes.last?.screen else { return false }
      return screen.is(\.crew)
        || screen.is(\.crewJoin)
        || screen.is(\.crewCreate)
        || screen.is(\.prepSchedule)
        || screen.is(\.prepFlags)
        || screen.is(\.prepChecklist)
    }

    var shouldHideTabBar: Bool {
      if authFlow.presentation != nil { return true }
      switch selectedTab {
      case .live:
        return festivalState.routes.count == 1
          || isNotificationInboxOnTop
          || isCrewOnTop
          || festivalState.routes.last?.screen.liveBoard?.alert != nil
          || festivalState.routes.last?.screen.liveBoard?.festivalSwitcher != nil
      case .timetable:
        return timetableState.destination?.schedulePick != nil
          || timetableState.setDetail != nil
          || timetableCoordinatorState.setList != nil
      case .my:
        // 마이의 설정·정보 화면은 탭바 없이 표시한다.
        return profileState.destination?.alert != nil
          || profileState.hidesTabBarForProfileRoute
          || profileState.destination?.settings?.destination?.account?.destination != nil
      case .flag:
        // Figma S05: 깃발 상세에서도 탭바(깃발 탭 선택)를 보인다.
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
    case openDeeplink(FestiCoreDeeplink)
    case festival(FestivalCoordinator.Action)
    case timetable(TimetableFeature.Action)
    case timetableCoordinator(TimetableCoordinator.Action)
    case flagCoordinator(FlagCoordinator.Action)
    case profileCoordinator(ProfileCoordinator.Action)
    case bearerEntry(PresentationAction<BearerEntryCoordinator.Action>)
    case auth(AuthCoordinator.Action)
    case session(SessionCoordinator.Action)
    case account(AccountCoordinator.Action)
    case authInputsChanged(previous: AuthInputs?, current: AuthInputs)
    case completePendingBookmark(id: String, userID: String, shouldBeBooked: Bool)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // 자식 기능이 세션을 바꾸면 같은 액션 안에서 이전 계정의 화면 데이터를 비운다.
      let previousSession = state.authInputs.session
      let effect = features.reduce(
        into: &state,
        action: action
      )
      state.reconcileAccountDisplayData(previousSession: previousSession)
      return effect
    }
  }

  @ReducerBuilder<State, Action>
  private var features: some ReducerOf<Self> {
    Scope(
      state: \.festivalState,
      action: \.festival
    ) {
      FestivalCoordinator()
    }
    Scope(
      state: \.timetableCoordinatorState,
      action: \.timetableCoordinator
    ) {
      TimetableCoordinator()
    }
    Scope(
      state: \.flagCoordinatorState,
      action: \.flagCoordinator
    ) {
      FlagCoordinator()
    }
    Scope(
      state: \.profileState,
      action: \.profileCoordinator
    ) {
      ProfileCoordinator()
    }
    Scope(
      state: \.authFlow,
      action: \.auth
    ) {
      AuthCoordinator()
    }
    Scope(
      state: \.authFlow,
      action: \.session
    ) {
      SessionCoordinator()
    }
    Scope(
      state: \.authFlow,
      action: \.account
    ) {
      AccountCoordinator()
    }

    Reduce { state, action in
      return handleRoute(
        state: &state,
        action: action
      )
    }
    .ifLet(
      \.$bearerEntry,
      action: \.bearerEntry
    ) {
      BearerEntryCoordinator()
    }
  }

  func handleRoute(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case let .tabTapped(tab):
      return .send(tab == state.selectedTab ? .tabReselected(tab) : .selectTab(tab))

    case let .selectTab(tab):
      return handleSelectTab(
        state: &state,
        tab: tab
      )

    case .tabReselected:
      return .none

    case let .openDeeplink(deeplink):
      return handleDeeplink(
        state: &state,
        deeplink: deeplink
      )

    case .festival,
         .timetable,
         .timetableCoordinator,
         .flagCoordinator,
         .profileCoordinator,
         .bearerEntry,
         .auth,
         .session,
         .account:
      return handleScopeAction(
        state: &state,
        action: action
      )

    case let .authInputsChanged(previous, current):
      return handleAuthInputsChanged(
        state: &state,
        previous: previous,
        current: current
      )

    case let .completePendingBookmark(id, userID, shouldBeBooked):
      return handleCompletePendingBookmark(
        state: &state,
        id: id,
        userID: userID,
        shouldBeBooked: shouldBeBooked
      )
    }
  }
}

// MARK: - 탭·딥링크

extension MainTabCoordinator {
  func handleSelectTab(
    state: inout State,
    tab: Tab
  ) -> Effect<Action> {
    select(
      tab,
      state: &state
    )
    switch tab {
    case .timetable:
      return syncTimetable(
        state: &state,
        appearing: true
      )
    case .flag:
      return syncFlag(state: &state)
    case .live:
      return .send(.festival(.reloadCachedPacks))
    case .my:
      return .none
    }
  }

  /// 위젯·푸시로 연 화면. 축제·크루 초대 경로는 라이브 탭, 깃발 경로는 깃발 탭, 공연 경로는 타임테이블 탭에서 연다.
  func handleDeeplink(
    state: inout State,
    deeplink: FestiCoreDeeplink
  ) -> Effect<Action> {
    switch deeplink {
    case .festivalList:
      select(
        .live,
        state: &state
      )
      return .send(.festival(.showFestivalList))

    case let .festival(id):
      select(
        .live,
        state: &state
      )
      return .send(.festival(.openWidgetFestival(id)))

    case let .set(festivalID, setID):
      // 공연 2시간 전 알림: 축제를 고른 뒤 타임테이블에서 그 공연 상세를 연다.
      return .concatenate(
        .send(.festival(.openWidgetFestival(festivalID))),
        .send(.selectTab(.timetable)),
        .send(.timetable(.view(.setTapped(setID))))
      )

    case let .crewInvite(code):
      select(
        .live,
        state: &state
      )
      return .send(.festival(.openCrewInvite(code)))

    case let .flag(id):
      let context = flagDetailContext(state)
      return .concatenate(
        .send(.selectTab(.flag)),
        .send(.flagCoordinator(.navigation(.showDetail(
          flagID: id,
          context: context
        ))))
      )
    }
  }

  private func select(
    _ tab: Tab,
    state: inout State
  ) {
    if state.selectedTab != tab { state.previousTab = state.selectedTab }
    state.selectedTab = tab
  }
}

// MARK: - 계정 입력·대기 예약

extension MainTabCoordinator {
  func handleAuthInputsChanged(
    state: inout State,
    previous: AuthInputs?,
    current: AuthInputs
  ) -> Effect<Action> {
    // 기수 등록은 로그인한 사용자의 흐름이라 세션이 바뀌면 닫는다.
    if previous?.session != current.session {
      state.bearerEntry = nil
    }
    return synchronizeAuthInputs(
      previous: previous,
      current: current
    )
  }

  func handleCompletePendingBookmark(
    state: inout State,
    id: String,
    userID: String,
    shouldBeBooked: Bool
  ) -> Effect<Action> {
    guard state.authFlow.verifiedUserID == userID,
          (state.authFlow.profile?.isEligible == true
            || (state.authFlow.profile == nil && bookedStore.offlineEligible(userID))) else { return .none }
    bookedStore.setBookmark(
      id,
      booked: shouldBeBooked,
      for: userID
    )
    return .run { send in
      await send(.festival(.reloadBookmarks(userID: userID)))
      await send(.festival(.bookmarkSaved(
        id: id,
        booked: shouldBeBooked
      )))
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
        await send(.auth(.login(.view(.contextChanged(
          login.context,
          flowMessage: login.message
        )))))
      }

      if previous?.signUp != current.signUp {
        if let signUp = current.signUp {
          await send(.auth(.signUp(.view(.flowChanged(
            isSubmitting: signUp.isSubmitting,
            message: signUp.message,
            termsUpdateExhausted: signUp.termsUpdateExhausted
          )))))
        } else if previous?.signUp != nil {
          await send(.auth(.signUp(.view(.sheetClosed))))
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
          || accountChanged
          || (oldSession.hasSession && !session.hasSession)
        if refreshAccountData {
          await send(.flagDirectory(.accountChanged))
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
}

extension MainTabCoordinator.Action {
  /// 깃발 탭 루트 디렉토리로 보내는 액션
  static func flagDirectory(_ action: FestivalFlagFeature.Action) -> Self {
    return .flagCoordinator(.router(.routeAction(
      id: 0,
      action: .directory(action)
    )))
  }
}

// MARK: - 계정 화면 데이터

extension MainTabCoordinator.State {
  /// 비동기 입력 액션 전에 개인 데이터가 화면에 남지 않도록 동기 정리한다.
  mutating func clearAccountDisplayData() {
    festivalState.clearAccountData()
    flagState.clearAccountData()
    timetableState.mySetIDs = []
    timetableState.scheduleSync = .idle
    timetableState.isScheduleLimitReached = false
    timetableState.setDetail = nil
    timetableState.destination = nil
    profileState.destination = nil
  }

  /// 확인한 계정이 바뀌면 이전 계정 데이터를 모두 비우고, 새로 로그인하면 비로그인 깃발 목록만 비운다.
  mutating func reconcileAccountDisplayData(previousSession: MainTabCoordinator.AuthInputs.Session) {
    let currentSession = authInputs.session
    if previousSession.userID != nil && previousSession.userID != currentSession.userID {
      clearAccountDisplayData()
    } else if !previousSession.hasSession && currentSession.hasSession {
      flagState.clearAccountData()
    }
  }
}
