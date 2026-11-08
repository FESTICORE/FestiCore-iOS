import ComposableArchitecture
import Foundation
import SwiftUI
import XCTest
@testable import Profile

/// Figma S13-J 화면 모드(Design 393 다크)를 고정 상태로 렌더한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCaptureAppearanceSettings() async throws {
    var state = AppearanceSettingsFeature.State()
    state.$mode.withLock { $0 = .system }
    let store = Store(initialState: state) {
      EmptyReducer<AppearanceSettingsFeature.State, AppearanceSettingsFeature.Action>()
    }
    try await capture(
      AppearanceSettingsView(store: store),
      name: "S13-J-appearance",
      size: CGSize(
        width: 393,
        height: 852
      )
    )
  }
}
