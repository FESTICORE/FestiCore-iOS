import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Festival

/// Figma S15-② 준비 안내 · 깃발(Design 393 다크)을 고정 상태로 렌더한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCapturePrepFlags() async throws {
    var state = FestivalPrepFlagsFeature.State(
      festivalID: "festival",
      zoneNames: ["zone_a": "리벳 옆 왼쪽"]
    )
    let flags = [
      prepFlag(
        "flg_1",
        name: "호락호락",
        followers: 1_284,
        tags: [
          "slam",
          "sing",
          "newbie"
        ]
      ),
      prepFlag(
        "flg_2",
        name: "떼창단",
        followers: 862,
        tags: [
          "slam",
          "sing"
        ]
      ),
      prepFlag(
        "flg_3",
        name: "기차놀이 원정대",
        followers: 540,
        tags: [
          "slam",
          "train"
        ]
      ),
      prepFlag(
        "flg_4",
        name: "첫락페 클럽",
        followers: 213,
        tags: [
          "newbie",
          "calm"
        ]
      ),
    ]
    state.flag.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival",
      activeFlags: [],
      followedFlags: [flags[0]],
      crew: nil,
      directoryFlags: flags
    )
    state.flag.viewState = .loaded
    state.flag.directory.sort = .followers
    let store = Store(initialState: state) {
      EmptyReducer<FestivalPrepFlagsFeature.State, FestivalPrepFlagsFeature.Action>()
    }
    try await capture(
      FestivalPrepFlagsView(store: store),
      name: "S15-2-prep-flags",
      size: CGSize(
        width: 393,
        height: 1058
      )
    )
  }

  func prepFlag(
    _ id: String,
    name: String,
    followers: Int,
    tags: [String]
  ) -> FestivalLiveBoardSnapshot.Flag {
    return FestivalLiveBoardSnapshot.Flag(
      id: id,
      name: name,
      status: "scheduled",
      zoneID: nil,
      activity: nil,
      thumbnailURL: nil,
      tags: tags,
      followerCount: followers,
      homeZoneID: "zone_a"
    )
  }
}
