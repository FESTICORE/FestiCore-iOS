import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct FestivalCoordinatorView: View {
  @Bindable var store: StoreOf<FestivalCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(\.routes, action: \.router)) { screen in
      switch screen.case {
      case let .festivalList(festivalStore):
        FestivalView(store: festivalStore)
      case let .liveBoard(liveBoardStore):
        FestivalLiveBoardRouteView(store: liveBoardStore)
          .swipeBackButtonHidden()
      case let .bearerBoard(bearerStore):
        BearerBoardView(store: bearerStore)
      case let .notificationInbox(inboxStore):
        NotificationInboxView(store: inboxStore)
          .swipeBackButtonHidden()
      case let .zoneMap(zoneMapStore):
        FestivalZoneMapView(store: zoneMapStore)
      case let .crew(crewStore):
        FestivalCrewView(store: crewStore)
          .swipeBackButtonHidden()
      case let .crewJoin(joinStore):
        FestivalCrewJoinView(store: joinStore)
          .swipeBackButtonHidden()
      case let .crewCreate(createStore):
        FestivalCrewCreateView(store: createStore)
          .swipeBackButtonHidden()
      case let .prepSchedule(scheduleStore):
        SchedulePickView(store: scheduleStore)
          .swipeBackButtonHidden()
      case let .prepFlags(flagsStore):
        FestivalPrepFlagsView(store: flagsStore)
          .swipeBackButtonHidden()
      }
    }
  }
}
