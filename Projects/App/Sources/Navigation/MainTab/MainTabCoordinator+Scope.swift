//
//  MainTabCoordinator+Scope.swift
//  FestiCore
//
//  Created by FestiCore on 11/11/26.
//

import ComposableArchitecture
import FeatureAssembly

// MARK: - 하위 기능 알림

extension MainTabCoordinator {
  /// 각 탭과 계정 흐름의 하위 기능이 보낸 액션을 기능별 처리 함수로 나눈다.
  func handleScopeAction(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case let .festival(festivalAction):
      return handleFestivalScope(
        state: &state,
        action: festivalAction
      )

    case let .timetable(timetableAction):
      return .send(.timetableCoordinator(.timetable(timetableAction)))

    case let .timetableCoordinator(timetableAction):
      return handleTimetableScope(
        state: &state,
        action: timetableAction
      )

    case let .flagCoordinator(flagAction):
      return handleFlagScope(
        state: &state,
        action: flagAction
      )

    case let .profileCoordinator(profileAction):
      return handleProfileScope(
        state: &state,
        action: profileAction
      )

    case let .bearerEntry(bearerAction):
      return handleBearerEntryScope(
        state: &state,
        action: bearerAction
      )

    case let .auth(authAction):
      return handleAuthScope(action: authAction)

    case let .session(sessionAction):
      return handleSessionScope(
        state: &state,
        action: sessionAction
      )

    case let .account(accountAction):
      return handleAccountScope(
        state: &state,
        action: accountAction
      )

    default:
      return .none
    }
  }
}

// MARK: - 라이브 탭

extension MainTabCoordinator {
  func handleFestivalScope(
    state: inout State,
    action: FestivalCoordinator.Action
  ) -> Effect<Action> {
    switch action {
    case .delegate(.loginRequested):
      return .send(.auth(.view(.loginRequested(nil))))

    case let .delegate(.bookmarkRequested(id)):
      // 예약 요청도 다른 축제 동작처럼 선택한 탭을 먼저 맞춘 뒤 프로필 확인을 시작한다.
      return .merge(
        syncSelectedTab(state: &state),
        .send(.session(.view(.bookmarkRequested(
          id: id,
          displayedAsBooked: flagBoard(state)?.bookedFestivalIDs.contains(id) == true
        ))))
      )

    case .delegate(.flagTabRequested):
      return .send(.selectTab(.flag))

    case .delegate(.crewLoginRequested):
      return .send(.auth(.view(.loginRequested(.crew))))

    case .delegate(.followLoginRequested):
      return .send(.auth(.view(.loginRequested(.follow))))

    case .delegate(.termsAcceptanceRequested):
      return .send(.session(.view(.retryProfile)))

    case let .delegate(.prepScheduleSaved(festivalID, setIDs)):
      // 준비 안내에서 저장한 내 일정을 같은 페스티벌의 타임테이블과 라이브 보드에 반영한다.
      if state.timetableState.festivalID == festivalID {
        state.timetableState.mySetIDs = setIDs
      }
      return .send(.festival(.myScheduleSaved(
        festivalID: festivalID,
        setIDs: setIDs
      )))

    case .delegate(.flagDirectoryRequested):
      return .send(.selectTab(.flag))

    case let .delegate(.packDirectionsRequested(festivalID, title)):
      return .concatenate(
        .send(.selectTab(.my)),
        .send(.profileCoordinator(.profile(.view(.openPackDirections(
          festivalID: festivalID,
          title: title
        )))))
      )

    default:
      return syncSelectedTab(state: &state)
    }
  }
}

// MARK: - 타임테이블 탭

extension MainTabCoordinator {
  func handleTimetableScope(
    state: inout State,
    action: TimetableCoordinator.Action
  ) -> Effect<Action> {
    switch action {
    case let .delegate(.scheduleSaved(id, ids)):
      return .send(.festival(.myScheduleSaved(
        festivalID: id,
        setIDs: ids
      )))

    case .delegate(.retry):
      guard let index = state.festivalState.routes.lastIndex(where: { $0.screen.is(\.liveBoard) }) else {
        return .none
      }
      return .send(.festival(.router(.routeAction(
        id: index,
        action: .liveBoard(.view(.onlineDetailOnAppear))
      ))))

    default:
      return .none
    }
  }
}

// MARK: - 깃발 탭

extension MainTabCoordinator {
  func handleFlagScope(
    state: inout State,
    action: FlagCoordinator.Action
  ) -> Effect<Action> {
    switch action {
    case let .delegate(.detailRequested(flagID)):
      return .send(.flagCoordinator(.navigation(.showDetail(
        flagID: flagID,
        context: flagDetailContext(state)
      ))))

    case .delegate(.loginRequested):
      return .send(.auth(.view(.loginRequested(nil))))

    case .delegate(.followLoginRequested):
      return .send(.auth(.view(.loginRequested(.follow))))

    case .delegate(.reportLoginRequested):
      return .send(.auth(.view(.loginRequested(.report))))

    case .delegate(.termsAcceptanceRequested):
      return .send(.session(.view(.retryProfile)))

    default:
      return .none
    }
  }
}

// MARK: - 마이 탭

extension MainTabCoordinator {
  func handleProfileScope(
    state: inout State,
    action: ProfileCoordinator.Action
  ) -> Effect<Action> {
    switch action {
    case .profile(.delegate(.loginRequested)):
      return .send(.auth(.view(.loginRequested(nil))))

    case .profile(.delegate(.bearerRequested)):
      return handleBearerRequested(state: &state)

    case .profile(.delegate(.profileRefreshRequested)):
      return .send(.session(.view(.retryProfile)))

    case .profile(.delegate(.logoutRequested)):
      return .send(.account(.view(.signOutRequested)))

    case .profile(.delegate(.withdrawRequested)):
      return .send(.account(.view(.withdrawRequested)))

    case let .profile(.delegate(.profileUpdated(user))):
      return .send(.session(.view(.profileUpdated(user))))

    case .profile(.destination(.presented(.packDetail(.delegate(.packDeleted))))),
         .profile(.destination(.presented(.packDetail(.delegate(.packChanged))))):
      return .send(.festival(.reloadCachedPacks))

    default:
      return .none
    }
  }

  func handleBearerEntryScope(
    state: inout State,
    action: PresentationAction<BearerEntryCoordinator.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.delegate(.closeRequested)):
      state.bearerEntry = nil
      return .none

    default:
      return .none
    }
  }

  /// 기수 등록은 로그인과 대상 페스티벌이 있어야 연다. 페스티벌을 정할 수 없으면 안내 팝업을 띄운다.
  private func handleBearerRequested(state: inout State) -> Effect<Action> {
    guard state.authFlow.hasSession else { return .send(.auth(.view(.loginRequested(nil)))) }
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
  }
}

// MARK: - 로그인·세션·계정

extension MainTabCoordinator {
  func handleAuthScope(action: AuthCoordinator.Action) -> Effect<Action> {
    guard case let .delegate(delegate) = action else { return .none }
    switch delegate {
    case let .profileFetchRequested(generation):
      return .send(.session(.view(.fetchProfile(generation: generation))))

    case let .signUpSubmitted(generation, result):
      return .send(.session(.view(.signUpSubmitted(
        generation: generation,
        result
      ))))

    case .retryProfileRequested:
      return .send(.session(.view(.retryProfile)))

    case let .pendingBookmarkResolved(resolution):
      return resolvePendingBookmark(resolution)
    }
  }

  func handleSessionScope(
    state: inout State,
    action: SessionCoordinator.Action
  ) -> Effect<Action> {
    guard case let .delegate(delegate) = action else { return .none }
    switch delegate {
    case .accountDataCleared:
      state.clearAccountDisplayData()
      return .send(.festival(.accountChanged))

    case .accountChanged:
      return .send(.festival(.accountChanged))

    case let .bookmarksReloadRequested(userID):
      return .send(.festival(.reloadBookmarks(userID: userID)))

    case let .pendingBookmarkResolved(resolution):
      return resolvePendingBookmark(resolution)

    case .accountOperationInterrupted:
      // 계정 작업이 같은 홈 범위에 있어 그 효과를 바로 취소한다.
      return .send(.account(.view(.cancelOperation)))
    }
  }

  func handleAccountScope(
    state: inout State,
    action: AccountCoordinator.Action
  ) -> Effect<Action> {
    switch action {
    case .delegate(.accountDataCleared):
      state.clearAccountDisplayData()
      return .send(.festival(.accountChanged))

    case .delegate(.sessionExpired):
      return .send(.session(.view(.sessionExpired)))

    default:
      return .none
    }
  }

  /// 세션·로그인 코디네이터가 정한 대로 대기 예약을 계정에 반영하거나 예약 목록만 다시 읽는다.
  private func resolvePendingBookmark(_ resolution: AuthFlowState.PendingBookmarkResolution) -> Effect<Action> {
    switch resolution {
    case let .reloadBookmarks(userID):
      return .send(.festival(.reloadBookmarks(userID: userID)))

    case let .complete(id, userID, shouldBeBooked):
      return .send(.completePendingBookmark(
        id: id,
        userID: userID,
        shouldBeBooked: shouldBeBooked
      ))
    }
  }
}
