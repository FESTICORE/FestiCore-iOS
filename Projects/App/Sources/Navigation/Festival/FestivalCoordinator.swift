import ComposableArchitecture
import CoreAssembly
import FeatureAssembly
import FestivalDomainInterface
import TCAFlow

@FlowCoordinator(screen: "FestivalScreen", navigation: true)
struct FestivalCoordinator {
  @Dependency(\.festivalPackUseCase) private var packUseCase
  @Dependency(\.continuousClock) private var clock
  private enum CancelID { case widgetLink, widgetLookupToast }

  @ObservableState
  struct State: Equatable {
    var routes: [Route<FestivalScreen.State>]

    init() {
      routes = [.root(.festivalList(.init()), embedInNavigationView: true)]
    }

    mutating func clearAccountData() {
      // 기수 보드는 로그인한 기수의 화면이라 계정이 바뀌면 닫는다.
      // 존 지도는 로그인 사용자의 팔로우·크루를 보여 주므로 함께 닫는다.
      routes.removeAll {
        $0.screen.is(\.bearerBoard) || $0.screen.is(\.notificationInbox) || $0.screen.is(\.zoneMap)
      }
      for index in routes.indices {
        switch routes[index].screen {
        case var .festivalList(board):
          board.clearAccountData()
          routes[index].screen = .festivalList(board)
        case var .liveBoard(board):
          board.clearAccountData()
          routes[index].screen = .liveBoard(board)
        case .bearerBoard, .notificationInbox, .zoneMap:
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
  }

  enum Delegate {
    case bookmarkRequested(String)
    case loginRequested
    case flagTabRequested
    case crewLoginRequested
    case followLoginRequested
    case flagDirectoryRequested
    case packDirectionsRequested(festivalID: String, title: String)
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
      case .bearerBoard, .notificationInbox, .zoneMap: return .none
      }
      return .send(.router(.routeAction(id: index, action: action)))

    case .showFestivalList:
      state.routes.removeAll { !$0.screen.is(\.festivalList) }
      return .cancel(id: CancelID.widgetLink)

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
      case .bearerBoard, .notificationInbox, .zoneMap:
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
      case .festivalList, .liveBoard, .bearerBoard, .notificationInbox, .zoneMap:
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
        case .bearerBoard, .notificationInbox, .zoneMap: return nil
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
        state.routes.removeAll { $0.screen.is(\.notificationInbox) }
      }
      return broadcast(state, .view(.sessionChanged(hasSession: hasSession, userID: userID)))

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
  /// 열린 모든 라우트에 같은 `FestivalFeature` 액션을 보낸다.
  func broadcast(_ state: State, _ action: FestivalFeature.Action) -> Effect<Action> {
    return .merge(state.routes.enumerated().map { index, route in
      let screenAction: FestivalScreen.Action
      switch route.screen {
      case .festivalList:
        screenAction = .festivalList(action)
      case .liveBoard:
        screenAction = .liveBoard(action)
      case .bearerBoard, .notificationInbox, .zoneMap:
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
  }
}

extension FestivalCoordinator.FestivalScreen.State: Equatable {}
