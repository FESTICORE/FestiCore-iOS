import ComposableArchitecture
import FeatureAssembly
import TCAFlow

@FlowCoordinator(screen: "HomeScreen", navigation: true)
struct HomeCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<HomeScreen.State>]

    init() {
      routes = [.root(.home(.init()), embedInNavigationView: true)]
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<HomeScreen>)
  }

  func handleRoute(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .router(.routeAction(id: _, action: .home(.view(.selectFestival(festivalID))))):
      state.routes.push(.liveBoard(.init(selectedFestivalID: festivalID)))
      return .none

    case .router(.routeAction(id: _, action: .liveBoard(.view(.backToFestivalList)))):
      state.routes.goBack()
      return .none

    case .router:
      return .none
    }
  }
}

extension HomeCoordinator {
  @Reducer
  enum HomeScreen {
    case home(HomeFeature)
    case liveBoard(HomeFeature)
  }
}

extension HomeCoordinator.HomeScreen.State: Equatable {}
