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
  @Dependency(\.date.now) private var now

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
    var flagCoordinatorState = FlagCoordinator.State()
    /// 깃발 탭 루트의 디렉토리. 축제·계정 동기화가 읽고 쓴다.
    var flagState: FestivalFlagFeature.State {
      get { return flagCoordinatorState.directory }
      set { flagCoordinatorState.directory = newValue }
    }
    var profileState = ProfileFeature.State()
    var loginState = LoginFeature.State()
    var authFlow = SessionCoordinator.State()
    /// 마이 '기수이신가요?'로 여는 기수 등록 흐름(전체 화면)
    @Presents var bearerEntry: BearerEntryCoordinator.State?

    /// 기수 코드를 넣을 페스티벌. 라이브 탭에서 연 페스티벌, 없으면 받은 팩이 하나일 때 그 팩이다.
    var bearerFestivalID: String? {
      if let festivalID = festivalState.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard?.selectedFestivalID {
        return festivalID
      }
      return profileState.packs.count == 1 ? profileState.packs.first?.id : nil
    }

    /// 모달이 열려도 기존 탭바 공간은 유지해 뒤 화면이 이동하지 않게 한다.
    var shouldReserveTabBarSpace: Bool {
      if selectedTab == .timetable, timetableState.destination?.schedulePick != nil || timetableCoordinatorState.setList != nil {
        return false
      }
      if selectedTab == .my, profileState.hidesTabBarForProfileRoute {
        return false
      }
      // 깃발 상세는 탭바 자리까지 화면을 쓴다.
      if selectedTab == .flag, flagCoordinatorState.isDetailOpen {
        return false
      }
      return selectedTab != .live || (festivalState.routes.count != 1 && !isNotificationInboxOnTop && !isCrewOnTop)
    }

    var isNotificationInboxOnTop: Bool {
      return festivalState.routes.last?.screen.is(\.notificationInbox) == true
    }

    /// 크루(S07)·참여 확인(S08)·크루 만들기·준비 안내(S15)는 아래 고정 영역이 있어 탭바 없이 표시한다.
    var isCrewOnTop: Bool {
      guard let screen = festivalState.routes.last?.screen else { return false }
      return screen.is(\.crew) || screen.is(\.crewJoin) || screen.is(\.crewCreate)
        || screen.is(\.prepSchedule) || screen.is(\.prepFlags) || screen.is(\.prepChecklist)
    }

    var shouldHideTabBar: Bool {
      if authFlow.presentation != nil { return true }
      switch selectedTab {
      case .live:
        return festivalState.routes.count == 1 || isNotificationInboxOnTop || isCrewOnTop
          || festivalState.routes.last?.screen.liveBoard?.alert != nil
          || festivalState.routes.last?.screen.liveBoard?.festivalSwitcher != nil
      case .timetable:
        return timetableState.destination?.schedulePick != nil || timetableState.setDetail != nil || timetableCoordinatorState.setList != nil
      case .my:
        // 마이의 설정·정보 화면은 탭바 없이 표시한다.
        return profileState.destination?.alert != nil
          || profileState.hidesTabBarForProfileRoute
          || profileState.destination?.account?.destination != nil
      case .flag:
        return flagCoordinatorState.isDetailOpen
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
    case login(LoginFeature.Action)
    case signUp(SignUpFlowCoordinator.Action)
    case session(SessionCoordinator.Action)
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
    /// 세션이 끝나 진행 중이던 로그아웃·탈퇴를 취소해야 한다.
    case accountOperationInterrupted
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
    Scope(state: \.festivalState, action: \.festival) {
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
    Scope(state: \.loginState, action: \.login) {
      LoginFeature()
    }
    Scope(
      state: \.authFlow.signUpFlow,
      action: \.signUp
    ) {
      SignUpFlowCoordinator()
    }
    Scope(
      state: \.authFlow,
      action: \.session
    ) {
      SessionCoordinator()
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

      case let .openDeeplink(deeplink):
        return openDeeplink(
          deeplink,
          state: &state
        )

      case .festival(.delegate(.loginRequested)):
        return .send(.delegate(.myLoginRequested))

      case .festival(.delegate(.flagTabRequested)):
        return .send(.selectTab(.flag))

      case .festival(.delegate(.crewLoginRequested)):
        return .send(.delegate(.myCrewLoginRequested))

      case .festival(.delegate(.followLoginRequested)):
        return .send(.delegate(.myFollowLoginRequested))

      case .festival(.delegate(.termsAcceptanceRequested)):
        return .send(.delegate(.myProfileRefreshRequested))

      case let .festival(.delegate(.prepScheduleSaved(
        festivalID,
        setIDs
      ))):
        // 준비 안내에서 저장한 내 일정을 같은 페스티벌의 타임테이블과 라이브 보드에 반영한다.
        if state.timetableState.festivalID == festivalID {
          state.timetableState.mySetIDs = setIDs
        }
        return .send(.festival(.myScheduleSaved(
          festivalID: festivalID,
          setIDs: setIDs
        )))

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

      case .timetableCoordinator(.delegate(.retry)):
        guard let index = state.festivalState.routes.lastIndex(where: { $0.screen.is(\.liveBoard) }) else { return .none }
        return .send(.festival(.router(.routeAction(
          id: index,
          action: .liveBoard(.view(.onlineDetailOnAppear))
        ))))

      case .timetableCoordinator:
        return .none

      case let .flagCoordinator(.delegate(.detailRequested(flagID))):
        return .send(.flagCoordinator(.navigation(.showDetail(
          flagID: flagID,
          context: flagDetailContext(state)
        ))))

      case .flagCoordinator(.delegate(.loginRequested)):
        return .send(.delegate(.myLoginRequested))

      case .flagCoordinator(.delegate(.followLoginRequested)):
        return .send(.delegate(.myFollowLoginRequested))

      case .flagCoordinator(.delegate(.termsAcceptanceRequested)):
        return .send(.delegate(.myProfileRefreshRequested))

      case .flagCoordinator, .delegate:
        return .none

      case let .session(.delegate(delegate)):
        return handleSessionDelegate(
          state: &state,
          delegate: delegate
        )

      case .session:
        return .none

      case let .authInputsChanged(
        previous,
        current
      ):
        // 기수 등록은 로그인한 사용자의 흐름이라 세션이 바뀌면 닫는다.
        if previous?.session != current.session {
          state.bearerEntry = nil
        }
        return synchronizeAuthInputs(
          previous: previous,
          current: current
        )

      case .profileCoordinator(.profile(.delegate(.loginRequested))):
        return .send(.delegate(.myLoginRequested))
      case .profileCoordinator(.profile(.delegate(.bearerRequested))):
        guard state.authFlow.hasSession else { return .send(.delegate(.myLoginRequested)) }
        guard let festivalID = state.bearerFestivalID else {
          state.profileState.destination = .alert(.alert(
            title: "페스티벌을 먼저 열어 주세요",
            message: "기수 코드는 페스티벌마다 달라요. 라이브 탭에서 기수로 참여할 페스티벌을 연 뒤 다시 눌러 주세요.",
            confirmTitle: "확인",
            cancelTitle: "닫기"
          ))
          return .none
        }
        state.bearerEntry = BearerEntryCoordinator.State(
          festivalID: festivalID,
          viewerUserID: state.authFlow.verifiedUserID
        )
        return .none
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

      case .bearerEntry(.presented(.delegate(.closeRequested))):
        state.bearerEntry = nil
        return .none
      case .bearerEntry:
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
    .ifLet(
      \.$bearerEntry,
      action: \.bearerEntry
    ) {
      BearerEntryCoordinator()
    }
  }

  private func handleSessionDelegate(
    state: inout State,
    delegate: SessionCoordinator.Delegate
  ) -> Effect<Action> {
    switch delegate {
    case .accountDataCleared:
      state.clearAccountDisplayData()
      return .send(.festival(.accountChanged))
    case .accountChanged:
      return .send(.festival(.accountChanged))
    case let .bookmarksReloadRequested(userID):
      return .send(.festival(.reloadBookmarks(userID: userID)))
    case let .pendingBookmarkCompleted(id, userID, shouldBeBooked):
      return .send(.completePendingBookmark(
        id: id,
        userID: userID,
        shouldBeBooked: shouldBeBooked
      ))
    case .accountOperationInterrupted:
      return .send(.delegate(.accountOperationInterrupted))
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
            termsUpdateExhausted: signUp.termsUpdateExhausted
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

  private func syncFlag(state: inout State) -> Effect<Action> {
    let board = flagBoard(state)
    let selectedID = board?.selectedFestivalID
    let pack = board?.displayDocument
    // 깃발 카드의 구역 칩은 선택 축제 팩의 구역 이름을 쓴다. 다른 축제의 팩이면 비운다.
    let zones = pack?.id == selectedID ? pack?.zones ?? [] : []
    let zoneNames = Dictionary(zones.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    if state.flagState.directory.zoneNames != zoneNames {
      state.flagState.directory.zoneNames = zoneNames
    }
    let festivalEffect: Effect<Action> = selectedID == state.flagState.festivalID
      ? .none : .send(.flagDirectory(.festivalChanged(selectedID)))
    // 열린 깃발 상세에 팩·내 일정·계정 변경을 알린다.
    guard state.flagCoordinatorState.isDetailOpen else { return festivalEffect }
    return .merge(
      festivalEffect,
      .send(.flagCoordinator(.navigation(.updateDetailContext(flagDetailContext(state)))))
    )
  }

  /// 깃발 탭이 따르는 축제 보드. 기수 보드·알림함은 라이브 보드 위에 덮이는 화면이라 그 아래 축제를 기준으로 삼는다.
  private func flagBoard(_ state: State) -> FestivalFeature.State? {
    return state.festivalState.routes.last { $0.screen.festivalBoard != nil }?.screen.festivalBoard
  }

  private func flagDetailContext(_ state: State) -> FestivalFlagDetailContext {
    return FestivalFlagDetailContext(
      board: flagBoard(state),
      snapshot: state.flagState.snapshot
    )
  }

  /// 위젯·푸시로 연 화면. 축제·크루 초대 경로는 라이브 탭, 깃발 경로는 깃발 탭, 공연 경로는 타임테이블 탭에서 연다.
  private func openDeeplink(
    _ deeplink: FestiCoreDeeplink,
    state: inout State
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
    case let .set(
      festivalID,
      setID
    ):
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

  /// 라이브 보드에서 고른 축제의 팩을 타임테이블에 옮긴다.
  /// 고른 축제가 없으면 이전 축제의 시간표가 남지 않게 비운다.
  private func syncTimetable(
    state: inout State,
    appearing: Bool
  ) -> Effect<Action> {
    let home = state.festivalState.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard
    let festivalID = home?.selectedFestivalID
    let pack = home?.displayDocument.flatMap { $0.id == festivalID ? $0 : nil }
    let sameFestival = festivalID == state.timetableState.festivalID
    let previousDays = sameFestival ? state.timetableState.days : []
    let days = pack.map {
      FestivalPackTimetableMapper.days(
        from: $0,
        previousDays: previousDays,
        imageURL: { home?.imageURL(for: $0) }
      )
    } ?? []
    let daysChanged = state.timetableState.days != days
    let selectedDayID = state.timetableState.selectedDay?.id
    state.timetableState.days = days
    state.timetableState.selectedDayIndex = days.firstIndex { $0.id == selectedDayID } ?? 0
    state.timetableState.lineup = pack.map(FestivalPackTimetableMapper.lineup) ?? []
    state.timetableState.source = FestivalPackTimetableMapper.source(pack?.source)
    if festivalID == nil {
      state.timetableState.contentStatus = .noFestival
    } else if let pack {
      state.timetableState.contentStatus = pack.performances.isEmpty ? .unpublished : .published
    } else if home?.onlineDetailLoading == true || (home?.connection == .loading && home?.onlineDetailFailed != true && home?.packWatchFailed != true) {
      state.timetableState.contentStatus = .loading
    } else {
      state.timetableState.contentStatus = .failed
    }
    state.timetableState.offlineMessage = nil
    if home?.connection == .offline, pack != nil {
      if let id = festivalID, let checkedAt = home?.cachedPacks[id]?.checkedAt {
        let minutes = max(
          0,
          Int(now.timeIntervalSince(checkedAt) / 60)
        )
        state.timetableState.offlineMessage = minutes == 0 ? "오프라인 · 방금 확인한 정보" : "오프라인 · \(minutes)분 전 정보"
      } else {
        state.timetableState.offlineMessage = "오프라인 · 저장된 정보"
      }
    }
    if let list = state.timetableCoordinatorState.setList {
      state.timetableCoordinatorState.setList = sameFestival
        ? TimetableSetListFeature.State(
          mode: list.mode,
          days: days,
          query: list.query
        )
        : nil
    }
    if !sameFestival {
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
