import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct TimetableCoordinatorView: View {
  @Bindable var store: StoreOf<TimetableCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(
      \.routes,
      action: \.router
    )) { screen in
      switch screen.case {
      case .timetable(let timetableStore):
        TimetableView(store: timetableStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      case .schedulePick(let pickStore):
        SchedulePickView(store: pickStore)
          .swipeBackButtonHidden()
      }
    }
  }
}
