import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Profile

/// 팩 상세의 S11 가는 길·S12 준비물을 고정 상태로 렌더한다(다크 393).
/// Figma에는 두 화면의 Design 393 판이 없어 와이어프레임(375x812) 구조와 비교한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCapturePackDetailStates() async throws {
    for tab in [
      PackDetailFeature.Tab.directions,
      PackDetailFeature.Tab.checklist,
    ] {
      var state = PackDetailFeature.State(
        festivalID: "festival",
        title: "펜타포트 락 페스티벌 2026"
      )
      state.tab = tab
      state.load = .loaded
      state.detail = packDetailFixture
      state.checklist = FestivalChecklist(checkedIDs: [
        "ticket",
        "id"
      ])
      let store = Store(initialState: state) {
        EmptyReducer<PackDetailFeature.State, PackDetailFeature.Action>()
      }
      try await capture(
        PackDetailView(store: store),
        name: tab == .directions ? "S11-directions" : "S12-checklist",
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }
}

extension FestivalS01VisualCaptureTests {
  var packDetailFixture: FestivalPackDetail {
    let source = FestivalPackDetail.Source(
      name: "주최측 공지 · 인천교통공사",
      verifiedAt: Date(timeIntervalSince1970: 1_792_134_000)
    )
    return FestivalPackDetail(
      pack: FestivalReceivedPack(
        id: "festival",
        name: "펜타포트 락 페스티벌 2026",
        packVersion: 3
      ),
      directions: FestivalPackDetail.Directions(
        lastShuttleAt: "23:40",
        lastTrainAt: "23:52",
        shuttle: FestivalPackDetail.Section(
          body: "송도역 2번 출구 ↔ 행사장 입구 왼쪽 셔틀 존. 15분 간격으로 운행하고, 사전 예약한 사람이 먼저 타요.",
          links: [FestivalPackDetail.Link(
            label: "셔틀 예약하기",
            url: URL(string: "https://example.com/shuttle")!
          )]
        ),
        transit: FestivalPackDetail.Section(body: "가장 가까운 역은 테크노파크역(인천 1호선)이에요. 행사장에서 걸어서 15분 정도 걸려요."),
        parking: FestivalPackDetail.Section(body: "행사장 P1·P2 주차장(유료). 22시 이후 출차가 몰려요."),
        memo: "헤드라이너가 끝나면 셔틀 줄이 30분 넘게 길어져요. 막차를 탈 거면 앵콜 전에 움직이세요.",
        naverMapURL: URL(string: "https://map.naver.com"),
        kakaoMapURL: URL(string: "https://map.kakao.com"),
        source: source
      ),
      checklist: [
        .init(
          id: "ticket",
          label: "모바일 티켓",
          required: true
        ),
        .init(
          id: "id",
          label: "신분증",
          required: true
        ),
        .init(
          id: "earplug",
          label: "귀마개"
        ),
        .init(
          id: "socks",
          label: "여분 양말"
        ),
        .init(
          id: "cash",
          label: "현금 조금"
        ),
      ],
      rules: [
        "유리병",
        "캔",
        "셀카봉",
        "접이식 의자",
        "드론",
      ],
      source: source
    )
  }
}
