import ComposableArchitecture
import FestiCoreDesignKit
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Festival

/// Figma S06 존 지도 A~J를 고정 상태로 렌더한다(라이트). 시각 자료 생성용이며 디자인 일치 판정 테스트는 아니다.
extension FestivalS01VisualCaptureTests {
  func testCaptureZoneMapStates() async throws {
    let now = Date()
    for scenario in ZoneMapScenario.allCases {
      let state = zoneMapState(
        scenario,
        now: now
      )
      let store = Store(initialState: state) {
        EmptyReducer<FestivalZoneMapFeature.State, FestivalZoneMapFeature.Action>()
      } withDependencies: {
        $0.date.now = now
      }
      try await withDependencies {
        $0.date.now = now
      } operation: {
        try await capture(
          FestivalZoneMapView(store: store)
            .safeAreaInset(
              edge: .bottom,
              spacing: .zero
            ) {
              FCTabBar(selection: .constant(.live))
            },
          name: scenario.rawValue,
          size: CGSize(
            width: 393,
            height: 852
          ),
          colorScheme: .light
        )
      }
    }
  }
}

extension FestivalS01VisualCaptureTests {
  enum ZoneMapScenario: String, CaseIterable {
    case basic = "S06-A-basic"
    case selected = "S06-B-selected"
    case cluster = "S06-C-cluster"
    case empty = "S06-D-empty"
    case stale = "S06-E-stale"
    case noFollow = "S06-F-no-follow"
    case offline = "S06-G-offline"
    case flagsOff = "S06-H-flags-off"
    case list = "S06-I-list"
    case changed = "S06-J-changed"
  }

  /// 시드(Backend `seed-zone-map.ts`)와 같은 393x600 지도 좌표
  var zoneMapZones: [FestivalZoneMap.Zone] {
    let rects: [(String, String, String, [Double], String?)] = [
      ("zon_rivet_front_left", "리벳 스테이지 앞 왼쪽", "무대 앞", [10, 42, 174, 98], nil),
      ("zon_rivet_center", "리벳 스테이지 중앙", "무대 앞", [10, 148, 108, 94], nil),
      ("zon_slam", "슬램 존", "슬램", [126, 148, 58, 94], nil),
      ("zon_rivet_back", "리벳 스테이지 뒤", "무대 뒤", [10, 250, 174, 58], nil),
      ("zon_wonder_front", "원더 스테이지 앞", "무대 앞", [209, 42, 174, 98], nil),
      ("zon_wonder_back", "원더 스테이지 뒤", "무대 뒤", [209, 148, 174, 90], nil),
      ("zon_tent", "TENT 앞", "무대 앞", [209, 246, 174, 62], "TENT 무대"),
      ("zon_grass", "잔디존", "휴식", [10, 338, 174, 160], nil),
      ("zon_fnb", "F&B 존", "먹거리", [209, 338, 174, 160], nil),
      ("zon_gate", "정문", "출입구", [140, 510, 168, 63], "GATE"),
    ]
    return rects.map { item in
      return FestivalZoneMap.Zone(
        id: item.0,
        name: item.1,
        kind: item.2,
        area: FestivalZoneMap.Area(
          x: item.3[0] / 393,
          y: item.3[1] / 600,
          width: item.3[2] / 393,
          height: item.3[3] / 600
        ),
        landmark: item.4
      )
    }
  }

  func zoneMap(
    flagsEnabled: Bool,
    hasLayout: Bool
  ) -> FestivalZoneMap {
    return FestivalZoneMap(
      festivalID: "festival",
      version: "zm-1",
      imageURL: nil,
      aspect: hasLayout ? 393.0 / 600.0 : nil,
      flagsEnabled: flagsEnabled,
      zones: zoneMapZones,
      stageHeaders: [
        .init(
          stageID: "stg_rivet",
          name: "RIVET STAGE",
          x: 10.0 / 393,
          y: 2.0 / 600,
          width: 174.0 / 393,
          nowPlaying: "터치드"
        ),
        .init(
          stageID: "stg_wonder",
          name: "WONDER STAGE",
          x: 209.0 / 393,
          y: 2.0 / 600,
          width: 174.0 / 393,
          nowPlaying: "LUCY"
        ),
      ]
    )
  }

  func zoneMapSnapshot(
    now: Date,
    followed: Bool,
    crew: Bool
  ) -> FestivalLiveBoardSnapshot {
    let rows: [(String, String, String, String, String, Double)] = [
      ("flg_horak", "호락호락", "zon_rivet_front_left", "active", "slam", 4),
      ("flg_maechang", "매창단", "zon_wonder_front", "active", "sing", 2),
      ("flg_red", "빨간바지", "zon_wonder_front", "active", "calm", 6),
      ("flg_center", "센터라인", "zon_rivet_center", "active", "sing", 3),
      ("flg_metal", "메탈크루", "zon_slam", "active", "slam", 1),
      ("flg_dive", "다이브앤롤", "zon_slam", "active", "slam", 5),
      ("flg_moshing", "모싱클럽", "zon_slam", "resting", "slam", 11),
      ("flg_picnic", "피크닉은락", "zon_grass", "active", "calm", 7),
      ("flg_snack", "야식원정대", "zon_fnb", "active", "train", 8),
    ]
    let flags = rows.map { row in
      return FestivalLiveBoardSnapshot.Flag(
        id: row.0,
        name: row.1,
        status: row.3,
        zoneID: row.2,
        activity: row.4,
        thumbnailURL: nil,
        updatedAt: now.addingTimeInterval(-row.5 * 60)
      )
    }
    let members: [FestivalLiveBoardSnapshot.Crew.Member] = [
      .init(
        id: "user-me",
        nickname: "로이",
        state: "here",
        zoneID: "zon_rivet_front_left",
        updatedAt: now
      ),
      .init(
        id: "user-junho",
        nickname: "준호",
        state: "here",
        zoneID: "zon_wonder_back",
        updatedAt: now.addingTimeInterval(-120)
      ),
      .init(
        id: "user-minji",
        nickname: "민지",
        state: "eating",
        zoneID: "zon_fnb",
        updatedAt: now.addingTimeInterval(-300)
      ),
      .init(
        id: "user-hansol",
        nickname: "한솔",
        state: "leaving",
        zoneID: "zon_gate",
        updatedAt: now.addingTimeInterval(-3_600)
      ),
    ]
    return FestivalLiveBoardSnapshot(
      festivalID: "festival",
      activeFlags: flags,
      followedFlags: followed ? Array(flags.prefix(2)) : [],
      crew: crew ? .init(
        id: "crew",
        name: "목 크루",
        members: members,
        ownerID: "user-me",
        gatherRequest: nil,
        gatherAvailableAt: nil
      ) : nil,
      receivedAt: now
    )
  }

  func zoneMapState(
    _ scenario: ZoneMapScenario,
    now: Date
  ) -> FestivalZoneMapFeature.State {
    let selected: String? = switch scenario {
    case .selected: "zon_rivet_front_left"
    case .cluster: "zon_slam"
    case .empty: "zon_tent"
    case .stale: "zon_gate"
    default: nil
    }
    let quiet = scenario == .noFollow
    var state = FestivalZoneMapFeature.State(
      festivalID: "festival",
      viewerUserID: "user-me",
      selectedZoneID: selected,
      snapshot: zoneMapSnapshot(
        now: now,
        followed: !quiet,
        crew: !quiet
      ),
      receivedAt: now
    )
    state.map = .loaded(zoneMap(
      flagsEnabled: scenario != .flagsOff,
      hasLayout: scenario != .list
    ))
    if scenario == .offline {
      state.live.isOffline = true
      state.live.receivedAt = now.addingTimeInterval(-185)
    }
    state.isMapChanged = scenario == .changed
    return state
  }
}
