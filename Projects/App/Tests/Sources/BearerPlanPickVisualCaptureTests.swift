import BearerDomainInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import XCTest
@testable import Bearer

/// 깃발 프로필(S10)의 '오늘 계획' 고르기를 고정 상태로 렌더한다(다크 393).
/// Figma에 이 화면이 따로 없어 내 일정 고르기(S15-1) 구성으로 그린다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCaptureBearerPlanPick() async throws {
    let sets = [
      BearerSet(
        id: "set_1",
        artist: "새소년",
        stageName: "원더 스테이지",
        startsAt: Date(timeIntervalSince1970: 1_786_089_600),
        endsAt: Date(timeIntervalSince1970: 1_786_093_200)
      ),
      BearerSet(
        id: "set_2",
        artist: "실리카겔",
        stageName: "리벳 스테이지",
        startsAt: Date(timeIntervalSince1970: 1_786_096_800),
        endsAt: Date(timeIntervalSince1970: 1_786_100_400)
      ),
      BearerSet(
        id: "set_3",
        artist: "잔나비",
        stageName: "리벳 스테이지",
        startsAt: Date(timeIntervalSince1970: 1_786_176_000),
        endsAt: Date(timeIntervalSince1970: 1_786_179_600)
      ),
    ]
    let store = Store(initialState: BearerPlanPickFeature.State(
      sets: sets,
      plan: ["set_2"]
    )) {
      EmptyReducer<BearerPlanPickFeature.State, BearerPlanPickFeature.Action>()
    }
    try await capture(
      BearerPlanPickView(store: store),
      name: "S10-F-plan-pick",
      size: CGSize(
        width: 393,
        height: 852
      )
    )
  }
}
