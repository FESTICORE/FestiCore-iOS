import ComposableArchitecture
import Foundation
import SwiftUI
import XCTest
@testable import Auth

/// Figma S14-2 가입 정보(Design 393 다크)를 고정 상태로 렌더한다. 시각 자료 생성용이다.
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
}
