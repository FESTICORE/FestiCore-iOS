import BearerDomainInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import XCTest
@testable import Bearer

/// Figma S10 깃발 프로필 등록 A~E(Design 393 다크)를 고정 상태로 렌더한다. 시각 자료 생성용이며 디자인 일치 판정 테스트는 아니다.
extension FestivalS01VisualCaptureTests {
  func testCaptureBearerProfileStates() async throws {
    for scenario in BearerProfileScenario.allCases {
      let store = Store(initialState: bearerProfileState(scenario)) {
        EmptyReducer<BearerProfileFeature.State, BearerProfileFeature.Action>()
      }
      try await capture(
        BearerProfileView(store: store),
        name: scenario.rawValue,
        size: CGSize(
          width: 393,
          height: scenario == .saved ? 852 : 1279
        )
      )
    }
  }
}

extension FestivalS01VisualCaptureTests {
  enum BearerProfileScenario: String, CaseIterable {
    case empty = "S10-A-empty"
    case filled = "S10-B-filled"
    case duplicateName = "S10-C-duplicate-name"
    case uploading = "S10-D-uploading"
    case saved = "S10-E-saved"
  }

  func bearerProfileState(_ scenario: BearerProfileScenario) -> BearerProfileFeature.State {
    var state = BearerProfileFeature.State(
      festivalID: "festival",
      flagID: "flag",
      profile: scenario == .empty ? BearerFlagProfile(
        id: "flag",
        name: ""
      ) : BearerFlagProfile(
        id: "flag",
        name: "호락호락",
        tags: [
          .slam,
          .sing,
          .newbie
        ],
        bio: "처음 와도 괜찮아요. 슬램은 앞쪽으로",
        plan: [
          "set-1",
          "set-2",
          "set-3"
        ],
        homeZoneID: "zone-1"
      ),
      isNewBearer: true
    )
    state.festivalName = "원더리벳 2026"
    state.zones = [
      BearerZone(
        id: "zone-1",
        name: "리벳 스테이지 앞 왼쪽"
      ),
      BearerZone(
        id: "zone-2",
        name: "리벳 스테이지 앞 오른쪽"
      ),
      BearerZone(
        id: "zone-3",
        name: "원더 스테이지 앞"
      ),
      BearerZone(
        id: "zone-4",
        name: "슬램 존"
      ),
    ]
    switch scenario {
    case .filled:
      state.uploadedPhotoData = bearerProfilePhotoData
    case .duplicateName:
      state.uploadedPhotoData = bearerProfilePhotoData
      state.nameError = "이미 있는 깃발 이름이에요. 다른 이름을 지어 주세요."
    case .uploading:
      // Figma S10-D: 고른 사진 위에 진행률을 겹친다. 빈 Data는 사진으로 읽히지 않아 빈 칸으로 그려진다.
      state.photoUpload = .uploading(
        data: bearerProfilePhotoData,
        progress: 0.64
      )
    case .saved:
      state.savedProfile = BearerFlagProfile(
        id: "flag",
        name: "호락호락",
        tags: [
          .slam,
          .sing,
          .newbie,
        ],
        bio: "처음 와도 괜찮아요. 슬램은 앞쪽으로",
        followerCount: 0,
        homeZoneID: "zone-1"
      )
    case .empty:
      break
    }
    return state
  }

  /// Figma S10 B~D의 고른 깃발 사진 자리. 단색 사각형 PNG다.
  var bearerProfilePhotoData: Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(
      width: 88,
      height: 88
    ))
    let image = renderer.image { context in
      UIColor.systemTeal.setFill()
      context.fill(CGRect(
        x: 0,
        y: 0,
        width: 88,
        height: 88
      ))
    }
    return image.pngData() ?? Data()
  }
}
