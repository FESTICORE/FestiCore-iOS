//
//  FlagFestivalTransferVisualCaptureTests.swift
//  FestiCoreTests
//
//  Created by FestiCore on 11/26/26.
//

import BearerDomainInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import XCTest
@testable import Bearer
@testable import Festival

/// 깃발 상세 '다른 페스티벌로 옮기기' 메뉴·페스티벌 고르기·확인 팝업을 라이트·다크로 렌더한다.
/// 이동 전용 시안 프레임이 없어 S05 깃발 상세·S14 D 등록 화면 스타일과 대조하는 시각 자료이며 디자인 일치 판정 테스트는 아니다.
extension FestivalS01VisualCaptureTests {
  func testCaptureFlagFestivalTransferStates() async throws {
    let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-07T09:50:00Z"))
    var detailState = flagDetailState(
      .basic,
      now: now
    )
    detailState.transferFestivalID = "fst_wonder"
    for colorScheme in [ColorScheme.dark, .light] {
      let suffix = colorScheme == .dark ? "dark" : "light"
      try await capture(
        FestivalFlagDetailView(store: Store(initialState: detailState) {
          EmptyReducer<FestivalFlagDetailFeature.State, FestivalFlagDetailFeature.Action>()
        }),
        name: "S10-transfer-A-detail-menu-\(suffix)",
        size: CGSize(
          width: 393,
          height: 1_092
        ),
        colorScheme: colorScheme
      )
      for scenario in TransferScenario.allCases {
        try await capture(
          BearerFestivalTransferView(store: Store(initialState: transferState(scenario)) {
            EmptyReducer<BearerFestivalTransferFeature.State, BearerFestivalTransferFeature.Action>()
          }),
          name: "\(scenario.rawValue)-\(suffix)",
          size: CGSize(
            width: 393,
            height: 852
          ),
          colorScheme: colorScheme
        )
      }
    }
  }
}

extension FestivalS01VisualCaptureTests {
  enum TransferScenario: String, CaseIterable {
    case picker = "S10-transfer-B-picker"
    case confirm = "S10-transfer-C-confirm"
    case failed = "S10-transfer-D-failed"
  }

  func transferState(_ scenario: TransferScenario) -> BearerFestivalTransferFeature.State {
    var state = BearerFestivalTransferFeature.State(
      flagID: "flg_horak",
      fromFestivalID: "fst_wonder"
    )
    state.festivals.load = .loaded
    state.festivals.received = [BearerFestivalOption(
      id: "fst_busan",
      name: "부산국제록페스티벌 2026",
      dateText: "11/30-12/1",
      hasPack: true
    )]
    state.festivals.upcoming = [
      BearerFestivalOption(
        id: "fst_seoul",
        name: "서울 파크 뮤직 페스티벌",
        dateText: "12/19-20",
        hasPack: false
      ),
      BearerFestivalOption(
        id: "fst_late",
        name: "늦은 페스티벌",
        dateText: "1/10",
        hasPack: false
      ),
    ]
    state.selectedFestivalID = "fst_busan"
    switch scenario {
    case .picker:
      break
    case .confirm:
      state.destination = .confirm(.bearerFestivalTransfer(festivalName: "부산국제록페스티벌 2026"))
    case .failed:
      state.errorMessage = BearerFestivalTransferFeature.transferMessage(for: .bearerLimit)
    }
    return state
  }
}
