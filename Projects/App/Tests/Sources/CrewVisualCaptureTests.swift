import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Festival

/// Figma S07 크루·S08 크루 참여 확인을 고정 상태로 렌더한다. 시안(Coloring · Light, 375×812)과 같은 라이트 모드로 그린다.
/// 시각 자료 생성용이며 디자인 일치 판정 테스트는 아니다.
extension FestivalS01VisualCaptureTests {
  func testCaptureCrewStates() async throws {
    for scenario in CrewScenario.allCases {
      let view: AnyView
      switch scenario {
      case .join:
        var state = FestivalCrewJoinFeature.State(
          code: "K7P2QX",
          hasSession: true
        )
        state.invite = crewInviteFixture
        state.load = .loaded
        view = AnyView(FestivalCrewJoinView(store: Store(initialState: state) {
          EmptyReducer<FestivalCrewJoinFeature.State, FestivalCrewJoinFeature.Action>()
        }))
      case .createName:
        // 크루 만들기는 Figma 시안이 없어 S07·S08과 같은 구성(상단 뒤로·아래 고정 버튼)으로 그린다(확인용).
        var state = FestivalCrewCreateFeature.State(festivalID: "festival")
        state.name = "펜타"
        view = AnyView(FestivalCrewCreateView(store: Store(initialState: state) {
          EmptyReducer<FestivalCrewCreateFeature.State, FestivalCrewCreateFeature.Action>()
        }))
      case .createInvite:
        var state = FestivalCrewCreateFeature.State(festivalID: "festival")
        state.step = .created(FestivalCrew(
          id: "crew",
          festivalID: "festival",
          name: "펜타",
          ownerID: "user-me",
          members: [],
          inviteCode: "K7P2QX",
          inviteExpiresAt: Date(timeIntervalSince1970: 1_786_287_600)
        ))
        view = AnyView(FestivalCrewCreateView(store: Store(initialState: state) {
          EmptyReducer<FestivalCrewCreateFeature.State, FestivalCrewCreateFeature.Action>()
        }))
      case .crew, .cooldown, .menu, .gather:
        let state = try crewState(scenario)
        view = AnyView(FestivalCrewView(store: Store(initialState: state) {
          EmptyReducer<FestivalCrewFeature.State, FestivalCrewFeature.Action>()
        }))
      }
      try await capture(
        view,
        name: scenario.rawValue,
        size: CGSize(
          width: 375,
          height: 812
        ),
        topInset: 44,
        colorScheme: .light
      )
      try await capture(
        view,
        name: "\(scenario.rawValue)-dark",
        size: CGSize(
          width: 375,
          height: 812
        ),
        topInset: 44
      )
    }
  }
}

extension FestivalS01VisualCaptureTests {
  enum CrewScenario: String, CaseIterable {
    case crew = "S07-A-crew"
    case cooldown = "S07-B-cooldown"
    case menu = "S07-C-menu"
    case gather = "S07-F-gather"
    case join = "S08-A-join"
    case createName = "S07-D-create-name"
    case createInvite = "S07-D-create-invite"
  }

  var crewInviteFixture: FestivalCrewInvite {
    return FestivalCrewInvite(
      code: "K7P2QX",
      crewName: "펜타 크루",
      festivalID: "fst_penta",
      festivalName: "펜타포트 락 페스티벌 2026",
      inviterNickname: "민지",
      memberCount: 4,
      // 시안의 8/8(토) 23:59 KST
      expiresAt: Date(timeIntervalSince1970: 1_786_201_140),
      memberPreview: [
        .init(
          nickname: "민지",
          avatarURL: nil
        ),
        .init(
          nickname: "로이",
          avatarURL: nil
        ),
        .init(
          nickname: "준",
          avatarURL: nil
        ),
      ]
    )
  }

  func crewState(_ scenario: CrewScenario) throws -> FestivalCrewFeature.State {
    let now = Date()
    // 마지막 날 종료 8/8 03:00 KST의 24시간 뒤가 시안의 "8/9(일) 03:00까지"다.
    let festival = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst_penta","name":"펜타포트 락 페스티벌 2026","days":[{"date":"2026-08-07","endsAt":"2026-08-07T18:00:00.000Z"}],"zones":[{"id":"zone_slam","name":"슬램 존"},{"id":"zone_fnb","name":"F&B"},{"id":"zone_toilet","name":"화장실 앞"},{"id":"zone_gate","name":"입구"}]}"#.utf8)
    )
    let members = [
      FestivalLiveBoardSnapshot.Crew.Member(
        id: "user-minji",
        nickname: "민지",
        state: "here",
        zoneID: "zone_slam",
        updatedAt: now.addingTimeInterval(-2 * 60 - 5)
      ),
      FestivalLiveBoardSnapshot.Crew.Member(
        id: "user-roy",
        nickname: "로이",
        state: "eating",
        zoneID: "zone_fnb",
        updatedAt: now.addingTimeInterval(-5 * 60 - 5)
      ),
      FestivalLiveBoardSnapshot.Crew.Member(
        id: "user-jun",
        nickname: "준",
        state: "toilet",
        zoneID: "zone_toilet",
        updatedAt: now.addingTimeInterval(-8 * 60 - 5)
      ),
      FestivalLiveBoardSnapshot.Crew.Member(
        id: "user-hyunjin",
        nickname: "현진",
        state: "leaving",
        zoneID: "zone_gate",
        updatedAt: now.addingTimeInterval(-60 * 60 - 5)
      )
    ]
    let isCooldown = scenario == .cooldown
    let isGather = scenario == .gather
    let live = FestivalLiveBoardSnapshot.Crew(
      id: "crew_penta",
      name: "펜타 크루",
      members: members,
      ownerID: "user-minji",
      gatherRequest: isCooldown || isGather
        ? .init(
          id: "gth_penta",
          zoneID: "zone_slam",
          byUserID: "user-minji",
          at: now.addingTimeInterval(isGather ? -5 : -2 * 60 - 5)
        )
        : nil,
      gatherAvailableAt: isCooldown ? now.addingTimeInterval(7 * 60 + 40) : nil
    )
    var state = FestivalCrewFeature.State(
      crewID: "crew_penta",
      festival: festival,
      // Figma S07 F는 받은 크루원(로이)의 화면이다.
      sessionUserID: isGather ? "user-roy" : "user-minji",
      live: live
    )
    state.crew = FestivalCrew(
      id: "crew_penta",
      festivalID: "fst_penta",
      name: "펜타 크루",
      ownerID: "user-minji",
      members: [],
      inviteCode: "K7P2QX",
      inviteExpiresAt: now.addingTimeInterval(24 * 60 * 60),
      live: live
    )
    state.load = .loaded
    if scenario == .menu {
      state.destination = .menu(FestivalCrewMenuFeature.State(
        crewName: "펜타 크루",
        members: members.dropFirst().map {
          FestivalCrewMenuFeature.State.Member(
            id: $0.id,
            nickname: $0.nickname
          )
        }
      ))
    }
    return state
  }
}
