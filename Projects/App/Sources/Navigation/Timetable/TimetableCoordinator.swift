import ComposableArchitecture
import FeatureAssembly
import TCAFlow

@Reducer
struct TimetableCoordinator {
  @ObservableState
  struct State: Equatable {
    var setList: TimetableSetListFeature.State?
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
      if let setList {
        routes.append(.push(.setList(setList)))
      }
      return routes
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<TimetableScreen>)
    case timetable(TimetableFeature.Action)
    case setList(TimetableSetListFeature.Action)
    case delegate(Delegate)
  }

  @CasePathable
  enum Delegate {
    case retry
    case scheduleSaved(
      festivalID: String,
      setIDs: Set<String>
    )
  }

  var body: some ReducerOf<Self> {
    Scope(
      state: \.timetableState,
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

      case .router(.routeAction(
        id: let id,
        action: .setList(let childAction)
      )) where id == 1:
        guard state.setList != nil else { return .none }
        return .send(.setList(childAction))

      case .router(.updateRoutes(let routes)):
        if state.setList != nil, !routes.contains(where: { $0.screen.is(\.setList) }) {
          state.setList = nil
        }
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

      case .timetable(.delegate(.search)):
        guard state.timetableState.destination == nil else { return .none }
        state.setList = .init(
          mode: .search,
          days: state.timetableState.days
        )
        return .none

      case .timetable(.delegate(.showChanges)):
        guard state.timetableState.destination == nil else { return .none }
        state.setList = .init(
          mode: .changes,
          days: state.timetableState.days
        )
        return .none

      case .timetable(.delegate(.retry)):
        return .send(.delegate(.retry))

      case .timetable(.delegate(.requestNotification)):
        return .send(.timetable(.view(.enablePackNotifications)))

      case .setList(.delegate(.close)):
        state.setList = nil
        return .none

      case let .setList(.delegate(.setSelected(id))):
        state.setList = nil
        return .send(.timetable(.view(.setTapped(id))))

      case .router, .timetable, .setList, .delegate:
        return .none
      }
    }
    .ifLet(
      \.setList,
      action: \.setList
    ) { TimetableSetListFeature() }
  }
}

extension TimetableCoordinator {
  @Reducer
  enum TimetableScreen {
    case timetable(TimetableFeature)
    case schedulePick(SchedulePickFeature)
    case setList(TimetableSetListFeature)
  }
}

extension TimetableCoordinator.TimetableScreen.State: Equatable {}
