import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct TimetableCoordinatorView: View {
  @Bindable var store: StoreOf<TimetableCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(
      state: \.routes,
      action: \.router
    )) { screen in
      switch screen.case {
      case .timetable(let timetableStore):
        TimetableView(store: timetableStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case .setList(let listStore):
        TimetableSetListView(store: listStore)
          .swipeBackButtonHidden()
      case .schedulePick(let pickStore):
        SchedulePickView(store: pickStore)
          .swipeBackButtonHidden()
      }
    }
  }
}
