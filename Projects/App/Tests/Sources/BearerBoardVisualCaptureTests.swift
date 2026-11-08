
import BearerDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import SwiftUI
import XCTest
@testable import Bearer

/// Figma S09 기수 보드 A~J를 고정 상태로 렌더한다. 시각 자료 생성용이며 디자인 일치 판정 테스트는 아니다.
extension FestivalS01VisualCaptureTests {
  func testCaptureBearerBoardStates() async throws {
    for scenario in BearerBoardScenario.allCases {
      let store = Store(initialState: bearerBoardState(scenario)) {
        EmptyReducer<BearerBoardFeature.State, BearerBoardFeature.Action>()
      }
      try await capture(
        BearerBoardView(store: store),
        name: scenario.rawValue,
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }
}

extension FestivalS01VisualCaptureTests {
  enum BearerBoardScenario: String, CaseIterable {
    case active = "S09-A-active"
    case zoneSheet = "S09-B-zone-sheet"
    case activitySheet = "S09-C-activity-sheet"
    case check = "S09-D-check"
    case resting = "S09-E-resting"
    case endConfirm = "S09-F-end-confirm"
    case ended = "S09-G-ended"
    case offline = "S09-H-offline"
    case scheduled = "S09-I-scheduled"
    case coBearer = "S09-J-co-bearer"
  }

  var bearerZones: [BearerZone] {
    let names = [
      "리벳 스테이지 앞 왼쪽",
      "리벳 스테이지 중앙",
      "리벳 스테이지 뒤",
      "원더 스테이지 앞",
      "원더 스테이지 뒤",
      "TENT 앞",
      "슬램 존",
      "잔디존",
      "F&B 존",
      "정문",
    ]
    return names.enumerated().map { index, name in
      return BearerZone(
        id: "zone-\(index)",
        name: name
      )
    }
  }

  func bearerBoardState(_ scenario: BearerBoardScenario) -> BearerBoardFeature.State {
    let now = Date()
    let viewer = "user-me"
    let status: BearerFlagStatus
    switch scenario {
    case .active, .zoneSheet, .activitySheet, .endConfirm:
      status = BearerFlagStatus(
        flagID: "flag",
        lifecycle: .active,
        zoneID: "zone-0",
        activity: .slam,
        updatedAt: now.addingTimeInterval(-4 * 60 - 5)
      )
    case .check, .offline:
      status = BearerFlagStatus(
        flagID: "flag",
        lifecycle: .active,
        zoneID: "zone-1",
        activity: .slam,
        updatedAt: now
      )
    case .resting:
      status = BearerFlagStatus(
        flagID: "flag",
        lifecycle: .resting,
        zoneID: "zone-2",
        activity: nil,
        updatedAt: now
      )
    case .ended:
      status = BearerFlagStatus(
        flagID: "flag",
        lifecycle: .ended,
        zoneID: "zone-1",
        activity: nil,
        updatedAt: now
      )
    case .scheduled:
      status = BearerFlagStatus(
        flagID: "flag",
        lifecycle: .scheduled,
        zoneID: nil,
        activity: nil,
        updatedAt: now
      )
    case .coBearer:
      status = BearerFlagStatus(
        flagID: "flag",
        lifecycle: .active,
        zoneID: "zone-1",
        activity: .sing,
        updatedAt: now.addingTimeInterval(-65),
        updatedBy: BearerCoBearer(
          userID: "user-minji",
          nickname: "민지"
        )
      )
    }
    var state = BearerBoardFeature.State(
      festivalID: "festival",
      flagID: "flag",
      viewerUserID: viewer
    )
    state.board = BearerBoard(
      profile: BearerFlagProfile(
        id: "flag",
        name: "호락호락"
      ),
      status: status,
      followerCount: 1_284
    )
    state.festival = BearerFestival(
      id: "festival",
      name: "리벳 페스티벌",
      zones: bearerZones
    )
    state.current = BearerBoardFeature.Current(status)
    state.lastActivity = .slam
    state.lastSyncedAt = now
    switch scenario {
    case .zoneSheet:
      state.destination = .zonePicker(.init(
        zones: bearerZones,
        selectedZoneID: "zone-0"
      ))
    case .activitySheet:
      state.destination = .activityPicker(.init(selected: .slam))
    case .check:
      state.check = BearerBoardFeature.Check(
        id: 1,
        title: "리벳 스테이지 중앙으로 바꿨어요",
        message: "팔로워에게 알렸어요"
      )
    case .endConfirm:
      state.destination = .alert(.bearerEndToday())
    case .offline:
      state.isOffline = true
      state.lastSyncedAt = now.addingTimeInterval(-3 * 60 - 5)
      state.pending = [
        BearerStatusRequest(
          change: .move(zoneID: "zone-1"),
          idempotencyKey: "pending-1",
          clientAt: now
        ),
      ]
    case .active, .resting, .ended, .scheduled, .coBearer:
      break
    }
    return state
  }
}
