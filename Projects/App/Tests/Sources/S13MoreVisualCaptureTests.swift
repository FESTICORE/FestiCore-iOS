import AuthDomainInterface
import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Bearer
@testable import Profile

/// Figma S13 F~I 기수 인증 코드와 More 마이 A(Design 393 다크)를 고정 상태로 렌더한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCaptureBearerClaimStates() async throws {
    for scenario in BearerClaimScenario.allCases {
      let store = Store(initialState: bearerClaimState(scenario)) {
        EmptyReducer<BearerClaimFeature.State, BearerClaimFeature.Action>()
      }
      try await capture(
        BearerClaimView(store: store),
        name: scenario.rawValue,
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }

  func testCaptureMoreProfile() async throws {
    var state = ProfileFeature.State()
    state.hasSession = true
    state.profile = AuthProfile(
      user: AuthUser(
        id: "user-minji",
        provider: "apple",
        email: nil,
        nickname: "민지",
        nicknameConfirmed: true,
        termsAcceptedAt: nil,
        termsVersion: "2026-10",
        pushOptIn: true,
        profileImageURL: nil
      ),
      currentTermsVersion: "2026-10"
    )
    state.packLoad = .loaded
    state.packs = [
      FestivalReceivedPack(
        id: "fst_wonder",
        name: "원더리벳 2026",
        packVersion: 3,
        checkedAt: Date(timeIntervalSince1970: 1_792_134_000)
      ),
      FestivalReceivedPack(
        id: "fst_busan",
        name: "부산국제록페스티벌 2026",
        packVersion: 2,
        latestPackVersion: 3
      ),
    ]
    // 시안 More A: "새 버전이 있어요 · 시간표 2개 변경"
    state.packChangedSets["fst_busan"] = 2
    let store = Store(initialState: state) {
      EmptyReducer<ProfileFeature.State, ProfileFeature.Action>()
    }
    try await capture(
      ProfileView(store: store),
      name: "More-A-profile",
      size: CGSize(
        width: 393,
        height: 940
      )
    )
  }

  /// 로그아웃 상태의 마이. 받은 팩·설정은 그대로 보이고 로그인 유도 카드가 맨 위에 온다.
  func testCaptureMoreGuest() async throws {
    var state = ProfileFeature.State()
    state.packLoad = .loaded
    state.packs = [
      FestivalReceivedPack(
        id: "fst_wonder",
        name: "원더리벳 2026",
        packVersion: 3,
        checkedAt: Date(timeIntervalSince1970: 1_792_134_000)
      ),
    ]
    let store = Store(initialState: state) {
      EmptyReducer<ProfileFeature.State, ProfileFeature.Action>()
    }
    try await capture(
      ProfileView(store: store),
      name: "More-A-guest",
      size: CGSize(
        width: 393,
        height: 940
      )
    )
  }
}

extension FestivalS01VisualCaptureTests {
  enum BearerClaimScenario: String, CaseIterable {
    case empty = "S13-F-claim-empty"
    case typing = "S13-G-claim-typing"
    case invalid = "S13-H-claim-invalid"
    case locked = "S13-I-claim-locked"
  }

  func bearerClaimState(_ scenario: BearerClaimScenario) -> BearerClaimFeature.State {
    var state = BearerClaimFeature.State(festivalID: "festival")
    let now = Date(timeIntervalSince1970: 1_792_134_000)
    state.now = now
    switch scenario {
    case .empty:
      break
    case .typing:
      state.code = "K7P2"
    case .invalid:
      state.code = "K7P2QX"
      state.failure = .invalid(remainingAttempts: 2)
      state.consecutiveFailures = 1
    case .locked:
      state.failure = .locked
      // 시안의 "9:42 뒤에 다시 입력할 수 있어요"
      state.lockedUntil = now.addingTimeInterval(9 * 60 + 42)
    }
    return state
  }
}
