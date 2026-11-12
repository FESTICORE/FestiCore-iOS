import ComposableArchitecture
import CoreAssembly
import FeatureAssembly
import FestivalDomainInterface
import TCAFlow

@FlowCoordinator(screen: "FestivalScreen", navigation: true)
struct FestivalCoordinator {
  @Dependency(\.festivalPackUseCase) private var packUseCase
  @Dependency(\.festivalScheduleUseCase) private var scheduleUseCase
  @Dependency(\.continuousClock) private var clock
  private enum CancelID { case widgetLink, widgetLookupToast }

  @ObservableState
  struct State: Equatable {
    var routes: [Route<FestivalScreen.State>]

    init() {
      routes = [.root(.festivalList(.init()), embedInNavigationView: true)]
    }

    /// 준비 안내(S15) 단계가 하나라도 열려 있다.
    var isPrepGuideOpen: Bool {
      return routes.contains {
        $0.screen.is(\.prepSchedule) || $0.screen.is(\.prepFlags) || $0.screen.is(\.prepChecklist)
      }
    }

    mutating func clearAccountData() {
      // 기수 보드·크루는 로그인한 사용자의 화면이라 계정이 바뀌면 닫는다.
      // 존 지도는 로그인 사용자의 팔로우·크루를 보여 주므로 함께 닫는다. 준비 안내도 계정의 일정·팔로우를 쓴다.
      routes.removeAll {
        $0.screen.is(\.bearerBoard) || $0.screen.is(\.notificationInbox) || $0.screen.is(\.zoneMap)
          || $0.screen.is(\.crew) || $0.screen.is(\.crewCreate)
          || $0.screen.is(\.prepSchedule) || $0.screen.is(\.prepFlags) || $0.screen.is(\.prepChecklist)
      }
      for index in routes.indices {
        switch routes[index].screen {
        case var .festivalList(board):
          board.clearAccountData()
          routes[index].screen = .festivalList(board)
        case var .liveBoard(board):
          board.clearAccountData()
          routes[index].screen = .liveBoard(board)
        case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist:
          break
        }
      }
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<FestivalScreen>)
    case delegate(Delegate)
    case reloadBookmarks(userID: String?)
    case reloadCachedPacks
    case bookmarkSaved(id: String, booked: Bool)
    case showFestivalList
    /// 기수 등록에서 고른 페스티벌을 핀(선택 저장)한다. 화면 경로는 바꾸지 않는다.
    case pinFestival(String)
    case openWidgetFestival(String)
    case widgetPackValidated(id: String, available: Bool)
    case widgetPackLookupFailed
    case widgetPackLookupToastExpired(Int)
    case foregrounded
    case backgrounded
    case remoteContentChanged
    case accountChanged
    case sessionChanged(hasSession: Bool, userID: String?)
    case myScheduleSaved(festivalID: String, setIDs: Set<String>)
    /// 크루 초대 링크. 참여 확인(S08)을 연다.
    case openCrewInvite(String)
    /// 준비 안내 1단계에 쓸 서버 내 일정. 읽지 못하면 nil이라 1단계를 건너뛴다.
    case prepScheduleLoaded(
      festivalID: String,
      setIDs: [String]?
    )
  }

  enum Delegate {
    case bookmarkRequested(String)
    case loginRequested
    case flagTabRequested
    case crewLoginRequested
    case followLoginRequested
    case flagDirectoryRequested
    case packDirectionsRequested(festivalID: String, title: String)
    /// 준비 안내에서 내 일정을 저장했다. 타임테이블에도 반영한다.
    case prepScheduleSaved(
      festivalID: String,
      setIDs: Set<String>
    )
    case termsAcceptanceRequested
  }

  func handleRoute(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .router(.routeAction(id: _, action: .festivalList(.view(.selectFestival(festivalID))))):
      let list = state.routes.first?.screen.festivalList
      var board = FestivalFeature.State(
        selectedFestivalID: festivalID,
        selectedCatalogItem: list?.catalog[id: festivalID]
      )
      if let list {
        if let pack = list.cachedPacks[festivalID] {
          board.cachedPacks[festivalID] = pack
        }
        board.bookedUserID = list.bookedUserID
        board.hasSession = list.hasSession
        board.sessionUserID = list.sessionUserID
        board.accountGeneration = list.accountGeneration
      }
      state.routes.push(.liveBoard(board))
      return .none

    case .router(.routeAction(id: _, action: .liveBoard(.view(.backToFestivalList)))):
      state.routes.goBack()
      return .none

    case .router(.routeAction(id: _, action: .liveBoard(.delegate(.notificationInboxRequested)))):
      guard state.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard?.hasSession == true else {
        return .send(.delegate(.loginRequested))
      }
      guard !state.routes.contains(where: { $0.screen.is(\.notificationInbox) }) else { return .none }
      state.routes.push(.notificationInbox(.init()))
      return .none

    case .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.flagTabRequested))
    )):
      return .send(.delegate(.flagTabRequested))

    case .router(.routeAction(id: _, action: .notificationInbox(.delegate(.backRequested)))):
      state.routes.goBack()
      return .none

    case let .router(.routeAction(id: inboxID, action: .notificationInbox(.delegate(.rowOpened(festivalID, markReadID))))):
      guard let boardIndex = state.routes.lastIndex(where: { $0.screen.is(\.liveBoard) }),
            let board = state.routes[boardIndex].screen.liveBoard else { return .none }
      let markReadEffect: Effect<Action> = markReadID.map { id in
        .send(.router(.routeAction(id: boardIndex, action: .liveBoard(.async(.markNotificationRead(id))))))
      } ?? .none
      guard let festivalID else { return markReadEffect }
      guard board.catalog.contains(where: { $0.id == festivalID }) else {
        return .merge(markReadEffect, .send(.router(.routeAction(
          id: inboxID, action: .notificationInbox(.view(.destinationUnavailable))
        ))))
      }
      state.routes.goBack()
      return board.selectedFestivalID == festivalID
        ? markReadEffect
        : .merge(markReadEffect, .send(.router(.routeAction(
          id: boardIndex, action: .liveBoard(.view(.selectFestival(festivalID)))
        ))))

    case let .router(.routeAction(id: _, action: .notificationInbox(.delegate(.unreadCountChanged(count))))):
      guard let boardIndex = state.routes.lastIndex(where: { $0.screen.is(\.liveBoard) }) else { return .none }
      return .send(.router(.routeAction(
        id: boardIndex,
        action: .liveBoard(.view(.notificationUnreadCountChanged(count)))
      )))

    case let .router(.routeAction(id: _, action: .festivalList(.delegate(.bookmarkRequested(festivalID))))),
         let .router(.routeAction(id: _, action: .liveBoard(.delegate(.bookmarkRequested(festivalID))))):
      return .send(.delegate(.bookmarkRequested(festivalID)))

    case let .router(.routeAction(id: _, action: .liveBoard(.delegate(.bearerBoardRequested(festivalID, flagID, userID))))):
      guard !state.routes.contains(where: { $0.screen.is(\.bearerBoard) }) else { return .none }
      state.routes.presentCover(.bearerBoard(.init(festivalID: festivalID, flagID: flagID, viewerUserID: userID)))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.zoneMapRequested(
        festivalID,
        zoneID
      )))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.zoneMap) }) else { return .none }
      let board = state.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard
      state.routes.push(.zoneMap(.init(
        festivalID: festivalID,
        viewerUserID: board?.sessionUserID,
        selectedZoneID: zoneID,
        snapshot: board?.liveBoard,
        receivedAt: board?.liveBoardReceivedAt
      )))
      return .none

    case .router(.routeAction(
      id: _,
      action: .zoneMap(.delegate(.backRequested))
    )):
      state.routes.goBack()
      return .none

    case .router(.routeAction(
      id: _,
      action: .zoneMap(.delegate(.flagDirectoryRequested))
    )):
      state.routes.goBack()
      return .send(.delegate(.flagTabRequested))

    case .router(.routeAction(id: _, action: .bearerBoard(.delegate(.closeRequested)))):
      state.routes.dismiss()
      return .none

    case let .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.crewRequested(crewID)))
    )):
      pushCrew(
        &state,
        crewID: crewID
      )
      return .none

    case let .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.crewCreateRequested(festivalID)))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.crewCreate) }) else { return .none }
      let board = state.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard
      state.routes.push(.crewCreate(FestivalCrewCreateFeature.State(
        festivalID: festivalID,
        festivalName: board?.selectedFestivalID == festivalID ? board?.displayDocument?.name : nil
      )))
      return .none

    case .router(.routeAction(
      id: _,
      action: .crewCreate(.delegate(.created))
    )):
      // 만들기 화면은 초대 단계로 남고, 돌아갈 라이브 보드의 크루 카드를 새로 받는다.
      return reloadLiveBoard(state)

    case let .router(.routeAction(
      id: _,
      action: .crewCreate(.delegate(.openCrewRequested(crewID)))
    )):
      // 만들기 화면을 크루 화면(S07)으로 바꾼다. 크루 화면에서 뒤로 가면 라이브 보드다.
      state.routes.removeAll { $0.screen.is(\.crewCreate) }
      pushCrew(
        &state,
        crewID: crewID
      )
      return .none

    case .router(.routeAction(
      id: _,
      action: .crewCreate(.delegate(.closeRequested))
    )):
      state.routes.goBack()
      return .none

    case .router(.routeAction(
      id: _,
      action: .crewCreate(.delegate(.loginRequested))
    )):
      state.routes.removeAll { $0.screen.is(\.crewCreate) }
      return .send(.delegate(.crewLoginRequested))

    case .router(.routeAction(
      id: _,
      action: .crew(.delegate(.backRequested))
    )):
      state.routes.goBack()
      return .none

    case .router(.routeAction(
      id: _,
      action: .crew(.delegate(.crewClosed))
    )):
      state.routes.removeAll { $0.screen.is(\.crew) }
      return reloadLiveBoard(state)

    case let .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.prepGuideRequested(festivalID)))
    )),
      let .router(.routeAction(
        id: _,
        action: .festivalList(.delegate(.prepGuideRequested(festivalID)))
      )):
      guard !state.isPrepGuideOpen else { return .none }
      return .run { send in
        do throws(FestivalScheduleError) {
          let schedule = try await scheduleUseCase.mySchedule(festivalID: festivalID)
          await send(.prepScheduleLoaded(
            festivalID: festivalID,
            setIDs: schedule.setIDs
          ))
        } catch {
          await send(.prepScheduleLoaded(
            festivalID: festivalID,
            setIDs: nil
          ))
        }
      }

    case let .prepScheduleLoaded(
      festivalID,
      setIDs
    ):
      guard !state.isPrepGuideOpen else { return .none }
      let board = state.routes.last(where: { $0.screen.festivalBoard != nil })?.screen.festivalBoard
      let pack = prepPackDocument(
        state,
        festivalID: festivalID
      )
      let days = pack.map {
        FestivalPackTimetableMapper.days(
          from: $0,
          imageURL: { board?.imageURL(for: $0) }
        )
      } ?? []
      // 서버 일정을 읽지 못했으면 덮어쓰지 않도록 1단계를 건너뛴다.
      guard let setIDs, !days.isEmpty else {
        pushPrepFlags(
          &state,
          festivalID: festivalID
        )
        return .none
      }
      state.routes.push(.prepSchedule(SchedulePickFeature.State(
        festivalID: festivalID,
        days: days,
        selectedSetIDs: Set(setIDs)
      )))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .prepSchedule(.delegate(.saved(
        festivalID,
        setIDs
      )))
    )):
      pushPrepFlags(
        &state,
        festivalID: festivalID
      )
      return .send(.delegate(.prepScheduleSaved(
        festivalID: festivalID,
        setIDs: setIDs
      )))

    case .router(.routeAction(
      id: _,
      action: .prepSchedule(.delegate(.skipped))
    )):
      guard let festivalID = state.routes.last(where: { $0.screen.is(\.prepSchedule) })?.screen.prepSchedule?.festivalID else { return .none }
      pushPrepFlags(
        &state,
        festivalID: festivalID
      )
      return .none

    case let .router(.routeAction(
      id: _,
      action: .prepFlags(.delegate(.finished))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.prepChecklist) }),
            let festivalID = state.routes.last(where: { $0.screen.is(\.prepFlags) })?.screen.prepFlags?.flag.festivalID else {
        return .none
      }
      let title = prepPackDocument(
        state,
        festivalID: festivalID
      )?.name ?? ""
      state.routes.push(.prepChecklist(PrepChecklistFeature.State(
        festivalID: festivalID,
        title: title
      )))
      return .none

    case .router(.routeAction(
      id: _,
      action: .prepSchedule(.delegate(.later))
    )),
      .router(.routeAction(
        id: _,
        action: .prepFlags(.delegate(.later))
      )),
      .router(.routeAction(
        id: _,
        action: .prepChecklist(.delegate(.later))
      )),
      .router(.routeAction(
        id: _,
        action: .prepChecklist(.delegate(.finished))
      )):
      state.routes.removeAll {
        $0.screen.is(\.prepSchedule) || $0.screen.is(\.prepFlags) || $0.screen.is(\.prepChecklist)
      }
      return .none

    case .router(.routeAction(
      id: _,
      action: .prepFlags(.delegate(.loginRequested))
    )):
      return .send(.delegate(.followLoginRequested))

    case .router(.routeAction(
      id: _,
      action: .prepFlags(.delegate(.termsAcceptanceRequested))
    )):
      return .send(.delegate(.termsAcceptanceRequested))

    case let .openCrewInvite(code):
      state.routes.removeAll { $0.screen.is(\.crewJoin) || $0.screen.is(\.crew) }
      let hasSession = state.routes.last(where: { $0.screen.festivalBoard != nil })?.screen.festivalBoard?.hasSession ?? false
      state.routes.push(.crewJoin(FestivalCrewJoinFeature.State(
        code: code,
        hasSession: hasSession
      )))
      return .none

    case .router(.routeAction(
      id: _,
      action: .crewJoin(.delegate(.closeRequested))
    )):
      state.routes.goBack()
      return .none

    case .router(.routeAction(
      id: _,
      action: .crewJoin(.delegate(.loginRequested))
    )):
      return .send(.delegate(.crewLoginRequested))

    case let .router(.routeAction(id: _,action: .crewJoin(.delegate(.joined(crewID, festivalID))))):
      state.routes.removeAll { $0.screen.is(\.crewJoin) }
      let board = state.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard
      let matches = board?.selectedFestivalID == festivalID
      state.routes.push(.crew(FestivalCrewFeature.State(
        crewID: crewID,
        festival: matches ? board?.displayDocument : nil,
        sessionUserID: board?.sessionUserID
      )))
      return reloadLiveBoard(state)

    case .router(.routeAction(id: _, action: .festivalList(.delegate(.loginRequested)))),
         .router(.routeAction(id: _, action: .liveBoard(.delegate(.loginRequested)))):
      return .send(.delegate(.loginRequested))

    case .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.crewLoginRequested))
    )):
      return .send(.delegate(.crewLoginRequested))

    case .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.followLoginRequested))
    )):
      return .send(.delegate(.followLoginRequested))

    case .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.flagDirectoryRequested))
    )):
      return .send(.delegate(.flagDirectoryRequested))

    case let .router(.routeAction(
      id: _,
      action: .liveBoard(.delegate(.packDirectionsRequested(
        festivalID,
        title
      )))
    )):
      return .send(.delegate(.packDirectionsRequested(
        festivalID: festivalID,
        title: title
      )))

    case let .reloadBookmarks(userID):
      return broadcast(state, .view(.reloadBookmarks(userID: userID)))

    case .reloadCachedPacks:
      return broadcast(state, .view(.reloadCachedPacks))

    case let .bookmarkSaved(id, booked):
      guard let index = state.routes.indices.last else { return .none }
      let action: FestivalScreen.Action
      switch state.routes[index].screen {
      case .festivalList: action = .festivalList(.view(.bookmarkSaved(id: id, booked: booked)))
      case .liveBoard: action = .liveBoard(.view(.bookmarkSaved(id: id, booked: booked)))
      case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist: return .none
      }
      return .send(.router(.routeAction(id: index, action: action)))

    case .showFestivalList:
      state.routes.removeAll { !$0.screen.is(\.festivalList) }
      return .cancel(id: CancelID.widgetLink)

    case let .pinFestival(id):
      return .send(.router(.routeAction(
        id: 0,
        action: .festivalList(.view(.selectFestival(id)))
      )))

    case let .openWidgetFestival(id):
      return .run { send in
        do {
          let packs = try await packUseCase.cachedPacks()
          let available = packs.contains { $0.festivalID == id }
          guard !Task.isCancelled else { return }
          await send(.widgetPackValidated(
            id: id,
            available: available
          ))
        } catch {
          guard !Task.isCancelled else { return }
          FestiCoreLogger.error(
            "위젯 축제 팩 조회 실패",
            category: .app
          )
          await send(.widgetPackLookupFailed)
        }
      }
      .cancellable(
        id: CancelID.widgetLink,
        cancelInFlight: true
      )

    case let .widgetPackValidated(
      id,
      available
    ):
      state.routes.removeAll { !$0.screen.is(\.festivalList) }
      guard available else { return .none }
      return .send(.router(.routeAction(
        id: 0,
        action: .festivalList(.view(.selectFestival(id)))
      )))

    case .widgetPackLookupFailed:
      guard let index = state.routes.lastIndex(where: {
        $0.screen.is(\.festivalList) || $0.screen.is(\.liveBoard)
      }) else { return .none }
      let revision: Int
      switch state.routes[index].screen {
      case var .festivalList(list):
        list.toast = .packDownloadFailed
        list.toastRevision += 1
        revision = list.toastRevision
        state.routes[index].screen = .festivalList(list)
      case var .liveBoard(board):
        board.toast = .packDownloadFailed
        board.toastRevision += 1
        revision = board.toastRevision
        state.routes[index].screen = .liveBoard(board)
      case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist:
        return .none
      }
      return .run { send in
        try await clock.sleep(for: .seconds(2))
        await send(.widgetPackLookupToastExpired(revision))
      }
      .cancellable(
        id: CancelID.widgetLookupToast,
        cancelInFlight: true
      )

    case let .widgetPackLookupToastExpired(revision):
      guard let index = state.routes.lastIndex(where: {
        $0.screen.is(\.festivalList) || $0.screen.is(\.liveBoard)
      }) else { return .none }
      switch state.routes[index].screen {
      case var .festivalList(list) where list.toastRevision == revision:
        list.toast = nil
        state.routes[index].screen = .festivalList(list)
      case var .liveBoard(board) where board.toastRevision == revision:
        board.toast = nil
        state.routes[index].screen = .liveBoard(board)
      case .festivalList, .liveBoard, .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist:
        break
      }
      return .none

    case .foregrounded:
      let targets = state.routes.enumerated().compactMap { index, route -> (Int, Bool)? in
        switch route.screen {
        case .festivalList:
          return (
            index,
            true
          )
        case .liveBoard:
          return (
            index,
            false
          )
        case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist: return nil
        }
      }
      return .run { @MainActor send in
        for target in targets {
          let action: FestivalScreen.Action = target.1
            ? .festivalList(.view(.foregroundChanged(true)))
            : .liveBoard(.view(.foregroundChanged(true)))
          await send(.router(.routeAction(
            id: target.0,
            action: action
          )))
        }
        for target in targets {
          let action: FestivalScreen.Action = target.1
            ? .festivalList(.view(.liveActivityOnAppear))
            : .liveBoard(.view(.liveActivityOnAppear))
          await send(.router(.routeAction(
            id: target.0,
            action: action
          )))
        }
      }

    case .remoteContentChanged:
      guard let target = state.routes.lastIndex(where: {
        $0.screen.is(\.festivalList) || $0.screen.is(\.liveBoard)
      }) else { return .none }
      let action: FestivalScreen.Action
      if state.routes[target].screen.is(\.festivalList) {
        action = .festivalList(.view(.remoteContentChanged))
      } else {
        action = .liveBoard(.view(.remoteContentChanged))
      }
      return .send(.router(.routeAction(
        id: target,
        action: action
      )))

    case .backgrounded:
      return broadcast(state, .view(.backgrounded))

    case .accountChanged:
      return broadcast(state, .view(.accountChanged))

    case let .sessionChanged(hasSession, userID):
      if !hasSession || state.routes.contains(where: {
        guard let board = $0.screen.liveBoard else { return false }
        return board.hasSession != hasSession || board.sessionUserID != userID
      }) {
        state.routes.removeAll {
          $0.screen.is(\.notificationInbox) || $0.screen.is(\.crew) || $0.screen.is(\.crewCreate)
            || $0.screen.is(\.prepSchedule)
        }
      }
      let joinUpdates: [Effect<Action>] = state.routes.indices.compactMap { index in
        guard state.routes[index].screen.is(\.crewJoin) else { return nil }
        return .send(.router(.routeAction(
          id: index,
          action: .crewJoin(.view(.sessionChanged(hasSession)))
        )))
      }
      let boardUpdate = broadcast(
        state,
        .view(.sessionChanged(
          hasSession: hasSession,
          userID: userID
        ))
      )
      return .merge([boardUpdate] + joinUpdates)

    case let .myScheduleSaved(festivalID, setIDs):
      return broadcast(state, .view(.myScheduleSaved(festivalID: festivalID, setIDs: setIDs)))

    case .delegate:
      return .none

    case .router:
      return .none
    }
  }
}

private extension FestivalCoordinator {
  /// 준비 안내 2단계(깃발 팔로우)를 올린다. 1단계가 있으면 그 위에 쌓아 뒤로 가면 1단계로 돌아간다.
  func pushPrepFlags(
    _ state: inout State,
    festivalID: String
  ) {
    guard !state.routes.contains(where: { $0.screen.is(\.prepFlags) }) else { return }
    var zoneNames: [String: String] = [:]
    for zone in prepPackDocument(
      state,
      festivalID: festivalID
    )?.zones ?? [] where zoneNames[zone.id] == nil {
      zoneNames[zone.id] = zone.name
    }
    state.routes.push(.prepFlags(FestivalPrepFlagsFeature.State(
      festivalID: festivalID,
      zoneNames: zoneNames
    )))
  }

  /// 준비 안내에 쓸 받아 둔 팩 문서
  func prepPackDocument(
    _ state: State,
    festivalID: String
  ) -> FestivalPackDocument? {
    let board = state.routes.last(where: { $0.screen.festivalBoard != nil })?.screen.festivalBoard
    return board?.packDocument(for: festivalID)
  }

  /// 라이브 보드 위에 크루 화면(S07)을 올린다. 이미 열려 있으면 그대로 둔다.
  func pushCrew(
    _ state: inout State,
    crewID: String
  ) {
    guard !state.routes.contains(where: { $0.screen.is(\.crew) }),
          let board = state.routes.last(where: { $0.screen.is(\.liveBoard) })?.screen.liveBoard else { return }
    state.routes.push(.crew(FestivalCrewFeature.State(
      crewID: crewID,
      festival: board.displayDocument,
      sessionUserID: board.sessionUserID,
      live: board.liveBoard?.crew
    )))
  }

  /// 크루가 바뀌었으니 라이브 보드의 크루 카드를 새로 받는다.
  func reloadLiveBoard(_ state: State) -> Effect<Action> {
    guard let index = state.routes.lastIndex(where: { $0.screen.is(\.liveBoard) }) else { return .none }
    return .send(.router(.routeAction(
      id: index,
      action: .liveBoard(.view(.retryLiveBoard))
    )))
  }

  /// 열린 모든 라우트에 같은 `FestivalFeature` 액션을 보낸다.
  func broadcast(_ state: State, _ action: FestivalFeature.Action) -> Effect<Action> {
    return .merge(state.routes.enumerated().map { index, route in
      let screenAction: FestivalScreen.Action
      switch route.screen {
      case .festivalList:
        screenAction = .festivalList(action)
      case .liveBoard:
        screenAction = .liveBoard(action)
      case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist:
        return .none
      }
      return .send(.router(.routeAction(id: index, action: screenAction)))
    })
  }
}

extension FestivalCoordinator {
  @Reducer
  enum FestivalScreen {
    case festivalList(FestivalFeature)
    case liveBoard(FestivalFeature)
    case bearerBoard(BearerBoardFeature)
    case notificationInbox(NotificationInboxFeature)
    case zoneMap(FestivalZoneMapFeature)
    case crew(FestivalCrewFeature)
    case crewJoin(FestivalCrewJoinFeature)
    case crewCreate(FestivalCrewCreateFeature)
    /// 준비 안내 1단계(S15-①) 내 일정 고르기
    case prepSchedule(SchedulePickFeature)
    /// 준비 안내 2단계(S15-②) 깃발 팔로우
    case prepFlags(FestivalPrepFlagsFeature)
    /// 준비 안내 3단계(S15-③) 준비물
    case prepChecklist(PrepChecklistFeature)
  }
}

extension FestivalCoordinator.FestivalScreen.State: Equatable {
  /// 축제 목록·라이브 보드 화면의 상태. 그 위에 덮인 화면이면 없다.
  var festivalBoard: FestivalFeature.State? {
    switch self {
    case let .festivalList(festival), let .liveBoard(festival): return festival
    case .bearerBoard, .notificationInbox, .zoneMap, .crew, .crewJoin, .crewCreate, .prepSchedule, .prepFlags, .prepChecklist: return nil
    }
  }
}
