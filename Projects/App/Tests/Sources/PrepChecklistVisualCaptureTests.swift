import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Profile

/// Figma S15-③ 준비 안내 · 준비물(Design 393 다크)을 고정 상태로 렌더한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCapturePrepChecklist() async throws {
    var state = PrepChecklistFeature.State(
      festivalID: "festival",
      title: "원더리벳 2026"
    )
    state.detail.load = .loaded
    state.detail.detail = packDetailFixture
    state.detail.checklist = FestivalChecklist(checkedIDs: [
      "ticket",
      "id"
    ])
    let store = Store(initialState: state) {
      EmptyReducer<PrepChecklistFeature.State, PrepChecklistFeature.Action>()
    }
    try await capture(
      PrepChecklistView(store: store),
      name: "S15-3-prep-checklist",
      size: CGSize(
        width: 393,
        height: 852
      )
    )
  }
}
