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
    .none
  }
}

extension HomeCoordinator {
  @Reducer
  enum HomeScreen {
    case home(HomeFeature)
  }
}

extension HomeCoordinator.HomeScreen.State: Equatable {}
