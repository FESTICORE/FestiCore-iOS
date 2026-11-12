import AuthDomainInterface
import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import SwiftUI
import XCTest
@testable import Bearer
@testable import Profile

/// Figma S13 F~I 기수 인증 코드, More 마이 A~C, S13-0 설정 홈을 고정 상태로 렌더한다. 시각 자료 생성용이다.
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

  /// More 마이 A 기본·B 로그아웃·C 받은 팩 없음과 S13-0 설정 홈을 라이트·다크로 렌더한다.
  func testCaptureMoreProfile() async throws {
    for colorScheme in [ColorScheme.light, .dark] {
      let suffix = colorScheme == .light ? "light" : "dark"
      let scenarios: [(name: String, signedIn: Bool, packs: [FestivalReceivedPack])] = [
        ("More-A-profile", true, moreSamplePacks),
        ("More-B-guest", false, moreSamplePacks),
        ("More-C-empty", true, []),
      ]
      for scenario in scenarios {
        let name = scenario.name
        let state = moreState(
          signedIn: scenario.signedIn,
          packs: scenario.packs
        )
        let store = Store(initialState: state) {
          EmptyReducer<ProfileFeature.State, ProfileFeature.Action>()
        }
        try await capture(
          ProfileView(store: store),
          name: "\(name)-\(suffix)",
          size: CGSize(
            width: 393,
            height: 852
          ),
          colorScheme: colorScheme
        )
      }

      let settings = SettingsHomeFeature.State(
        profile: moreMinjiProfile,
        hasSession: true
      )
      try await capture(
        SettingsHomeView(store: Store(initialState: settings) {
          EmptyReducer<SettingsHomeFeature.State, SettingsHomeFeature.Action>()
        }),
        name: "S13-0-settings-home-\(suffix)",
        size: CGSize(
          width: 393,
          height: 852
        ),
        colorScheme: colorScheme
      )
    }
  }

  var moreMinjiProfile: AuthProfile {
    return AuthProfile(
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
  }

  var moreSamplePacks: [FestivalReceivedPack] {
    return [
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
  }

  func moreState(
    signedIn: Bool,
    packs: [FestivalReceivedPack]
  ) -> ProfileFeature.State {
    var state = ProfileFeature.State()
    if signedIn {
      state.hasSession = true
      state.profile = moreMinjiProfile
    }
    state.packLoad = .loaded
    state.packs = packs
    // 시안 More A·B: "새 버전이 있어요 · 시간표 2개 변경"
    if packs.contains(where: { $0.id == "fst_busan" }) {
      state.packChangedSets["fst_busan"] = 2
    }
    return state
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
