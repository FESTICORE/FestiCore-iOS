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
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<FestivalScreen>)
    case delegate(Delegate)
    case reloadBookmarks(userID: String?)
  }

  enum Delegate {
    case bookmarkRequested(String)
  }

  func handleRoute(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .router(.routeAction(id: _, action: .festivalList(.view(.selectFestival(festivalID))))):
      var board = FestivalFeature.State(selectedFestivalID: festivalID)
      board.bookedUserID = state.routes.first?.screen.festivalList?.bookedUserID
      state.routes.push(.liveBoard(board))
      return .none

    case .router(.routeAction(id: _, action: .liveBoard(.view(.backToFestivalList)))):
      state.routes.goBack()
      return .none

    case let .router(.routeAction(id: _, action: .festivalList(.delegate(.bookmarkRequested(festivalID))))),
         let .router(.routeAction(id: _, action: .liveBoard(.delegate(.bookmarkRequested(festivalID))))):
      return .send(.delegate(.bookmarkRequested(festivalID)))

    case let .reloadBookmarks(userID):
      return .merge(state.routes.enumerated().map { index, route in
        let screenAction: FestivalScreen.Action
        switch route.screen {
        case .festivalList:
          screenAction = .festivalList(.reloadBookmarks(userID: userID))
        case .liveBoard:
          screenAction = .liveBoard(.reloadBookmarks(userID: userID))
        }
        return .send(.router(.routeAction(id: index, action: screenAction)))
      })

    case .delegate:
      return .none

    case .router:
      return .none
    }
  }
}

extension FestivalCoordinator {
  @Reducer
  enum FestivalScreen {
    case festivalList(FestivalFeature)
    case liveBoard(FestivalFeature)
  }
}

extension FestivalCoordinator.FestivalScreen.State: Equatable {}
