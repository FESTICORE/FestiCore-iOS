import ComposableArchitecture
import FeatureAssembly

/// 시간표 화면과 일정 선택 화면의 라우팅 상태.
@Reducer
enum TimetableScreen {
  case timetable(TimetableFeature)
  case schedulePick(SchedulePickFeature)
}

extension TimetableScreen.State: Equatable {}
