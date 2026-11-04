import ComposableArchitecture
import FeatureAssembly
import TCAFlow

@FlowCoordinator(screen: "FestivalScreen", navigation: true)
struct FestivalCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<FestivalScreen.State>]

    init() {
      routes = [.root(.festivalList(.init()), embedInNavigationView: true)]
    }

    mutating func clearAccountData() {
      // 기수 보드는 로그인한 기수의 화면이라 계정이 바뀌면 닫는다.
      routes.removeAll { $0.screen.is(\.bearerBoard) || $0.screen.is(\.notificationInbox) }
      for index in routes.indices {
        switch routes[index].screen {
        case var .festivalList(board):
          board.clearAccountData()
          routes[index].screen = .festivalList(board)
        case var .liveBoard(board):
          board.clearAccountData()
          routes[index].screen = .liveBoard(board)
        case .bearerBoard, .notificationInbox:
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
    case bookmarkSaved(id: String, booked: Bool)
    case accountChanged
    case sessionChanged(hasSession: Bool, userID: String?)
    case myScheduleSaved(festivalID: String, setIDs: Set<String>)
  }

  enum Delegate {
    case bookmarkRequested(String)
    case loginRequested
  }

  func handleRoute(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .router(.routeAction(id: _, action: .festivalList(.view(.selectFestival(festivalID))))):
      var board = FestivalFeature.State(selectedFestivalID: festivalID)
      if let list = state.routes.first?.screen.festivalList {
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

    case .router(.routeAction(id: _, action: .bearerBoard(.delegate(.closeRequested)))):
      state.routes.dismiss()
      return .none

    case .router(.routeAction(id: _, action: .festivalList(.delegate(.loginRequested)))),
         .router(.routeAction(id: _, action: .liveBoard(.delegate(.loginRequested)))):
      return .send(.delegate(.loginRequested))

    case let .reloadBookmarks(userID):
      return broadcast(state, .view(.reloadBookmarks(userID: userID)))

    case let .bookmarkSaved(id, booked):
      guard let index = state.routes.indices.last else { return .none }
      let action: FestivalScreen.Action
      switch state.routes[index].screen {
      case .festivalList: action = .festivalList(.view(.bookmarkSaved(id: id, booked: booked)))
      case .liveBoard: action = .liveBoard(.view(.bookmarkSaved(id: id, booked: booked)))
      case .bearerBoard, .notificationInbox: return .none
      }
      return .send(.router(.routeAction(id: index, action: action)))

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
    .merge(state.routes.enumerated().map { index, route in
      let screenAction: FestivalScreen.Action
      switch route.screen {
      case .festivalList:
        screenAction = .festivalList(action)
      case .liveBoard:
        screenAction = .liveBoard(action)
      case .bearerBoard, .notificationInbox:
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
  }
}

extension FestivalCoordinator.FestivalScreen.State: Equatable {}
