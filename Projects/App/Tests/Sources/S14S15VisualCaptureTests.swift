import ComposableArchitecture
import Foundation
import SwiftUI
import TimetableDomainInterface
import XCTest
@testable import Auth
@testable import Timetable

/// Figma S14-2 가입 정보·S15-1 내 일정 고르기(Design 393 다크)를 고정 상태로 렌더한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCaptureSignUp() async throws {
    var state = SignUpFeature.State()
    state.nickname = "민지"
    let store = Store(initialState: state) {
      EmptyReducer<SignUpFeature.State, SignUpFeature.Action>()
    }
    try await capture(
      SignUpView(store: store),
      name: "S14-2-signup",
      size: CGSize(
        width: 393,
        height: 852
      )
    )
  }

  /// Figma S14 A 로그인 첫 진입(601:23327, 라이트)
  func testCaptureLaunchLogin() async throws {
    let store = Store(initialState: LoginFeature.State()) {
      EmptyReducer<LoginFeature.State, LoginFeature.Action>()
    }
    try await capture(
      LoginView(store: store),
      name: "S14-A-launch-login",
      size: CGSize(
        width: 393,
        height: 852
      ),
      colorScheme: .light
    )
  }

  /// Figma S15-1 내 일정 고르기: 11/20 금 다섯 무대 중 coldrain·SPYAIR를 골라 20분 겹친 상태
  func testCaptureSchedulePick() async throws {
    let day = TimetableDay(
      id: "day1",
      title: "11/20 금",
      date: Date(timeIntervalSince1970: 1_795_100_400),
      stages: [
        TimetableStage(
          id: "livet",
          name: "LIVET STAGE"
        ),
        TimetableStage(
          id: "wonder",
          name: "WONDER STAGE"
        ),
      ],
      sets: [
        TimetableSet(
          id: "saucy",
          artist: "Saucy Dog",
          stageID: "livet",
          start: 930,
          end: 980
        ),
        TimetableSet(
          id: "coldrain",
          artist: "coldrain",
          stageID: "wonder",
          start: 1000,
          end: 1050
        ),
        TimetableSet(
          id: "spyair",
          artist: "SPYAIR",
          stageID: "livet",
          start: 1030,
          end: 1080
        ),
        TimetableSet(
          id: "natori",
          artist: "natori",
          stageID: "wonder",
          start: 1100,
          end: 1160
        ),
        TimetableSet(
          id: "oral",
          artist: "THE ORAL CIGARETTES",
          stageID: "wonder",
          start: 1190,
          end: 1260
        ),
      ]
    )
    let days = ["11/21 토", "11/22 일"].enumerated().map { index, title in
      return TimetableDay(
        id: "day\(index + 2)",
        title: title,
        date: day.date.addingTimeInterval(Double(index + 1) * 86_400),
        stages: day.stages,
        sets: []
      )
    }
    let store = Store(initialState: SchedulePickFeature.State(
      festivalID: "festival",
      days: [day] + days,
      selectedSetIDs: [
        "coldrain",
        "spyair",
      ]
    )) {
      EmptyReducer<SchedulePickFeature.State, SchedulePickFeature.Action>()
    }
    try await capture(
      SchedulePickView(store: store),
      name: "S15-1-schedule-pick",
      size: CGSize(
        width: 393,
        height: 852
      )
    )
  }
}
