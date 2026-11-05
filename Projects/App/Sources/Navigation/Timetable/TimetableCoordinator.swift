import ComposableArchitecture
import FeatureAssembly
import TCAFlow

@Reducer
struct TimetableCoordinator {
  @ObservableState
  struct State: Equatable {
    var timetableState = TimetableFeature.State(
      days: [],
      source: ""
    )

    var routes: [Route<TimetableScreen.State>] {
      var routes: [Route<TimetableScreen.State>] = [
        .root(
          .timetable(timetableState),
          embedInNavigationView: true
        )
      ]
      if let pick = timetableState.destination?.schedulePick {
        routes.append(.push(.schedulePick(pick)))
      }
      return routes
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<TimetableScreen>)
    case timetable(TimetableFeature.Action)
    case delegate(Delegate)
  }

  @CasePathable
  enum Delegate {
    case scheduleSaved(
      festivalID: String,
      setIDs: Set<String>
    )
  }

  var body: some ReducerOf<Self> {
    Scope(
      \.timetableState,
      action: \.timetable
    ) {
      TimetableFeature()
    }

    Reduce { state, action in
      switch action {
      case .router(.routeAction(
        id: let id,
        action: .timetable(let childAction)
      )) where id == 0:
        return .send(.timetable(childAction))

      case .router(.routeAction(
        id: let id,
        action: .schedulePick(let childAction)
      )) where id == 1:
        guard state.timetableState.destination?.schedulePick != nil else { return .none }
        return .send(.timetable(.destination(.presented(.schedulePick(childAction)))))

      case .router(.updateRoutes(let routes)):
        guard state.timetableState.destination?.schedulePick != nil,
          !routes.contains(where: { $0.screen.is(\.schedulePick) })
        else { return .none }
        return .send(.timetable(.destination(.dismiss)))

      case .timetable(.delegate(.scheduleSaved(
        let id,
        let ids
      ))):
        return .send(.delegate(.scheduleSaved(
          festivalID: id,
          setIDs: ids
        )))

      case .router, .timetable, .delegate:
        return .none
      }
    }
  }
}
