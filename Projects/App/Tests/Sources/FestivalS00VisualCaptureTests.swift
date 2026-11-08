import ComposableArchitecture
import FestiCorePackInterface
import FestivalDomainInterface
import Onboarding
import SwiftUI
import UIKit
import XCTest
@testable import Festival

/// Figma S00(목록·검색)과 Onboarding 1~4를 시안 프레임 크기 그대로 렌더한다.
/// 시안과 같은 393pt 창 한 장이 시안 PNG 한 장에 대응한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCaptureFestivalListStates() async throws {
    for scenario in FestivalListScenario.allCases {
      let state = try festivalListFixture(scenario)
      // 목록 View의 @Dependency(\.date)가 렌더 중 고정 시각을 읽도록 생성과 렌더를 같은 범위에 둔다.
      try await withDependencies {
        $0.date.now = festivalListNow
      } operation: {
        try await capture(
          FestivalView(store: Store(initialState: state) {
            EmptyReducer<FestivalFeature.State, FestivalFeature.Action>()
          }),
          name: scenario.rawValue,
          size: CGSize(
            width: 393,
            height: scenario.referenceHeight
          )
        )
      }
    }
  }

  func testCaptureOnboardingPages() async throws {
    for page in 0..<4 {
      var state = OnboardingFeature.State()
      state.page = page
      try await capture(
        OnboardingView(store: Store(initialState: state) {
          EmptyReducer<OnboardingFeature.State, OnboardingFeature.Action>()
        }),
        name: "Onboarding\(page + 1)",
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }
}

private extension FestivalS01VisualCaptureTests {
  enum FestivalListScenario: String, CaseIterable {
    case all = "S00-list-all"
    case booked = "S00-list-booked"
    case bookmarkToast = "S00-list-all-bookmark"
    case searchResult = "S00-search-result"
    case searchEmpty = "S00-search-empty"
    case searchRecent = "S00-search-recent"

    /// 시안 PNG 높이. 스크롤 없이 시안 프레임 전체를 한 창에 그린다.
    var referenceHeight: CGFloat {
      switch self {
      case .all: return 1802
      case .booked: return 1844
      case .bookmarkToast: return 1826
      case .searchResult, .searchEmpty, .searchRecent: return 852
      }
    }
  }

  /// 시안의 D-2(10/24)·D-29(11/20)·D-58(12/19)이 나오는 서울 기준 시각
  var festivalListNow: Date {
    return ISO8601DateFormatter().date(from: "2026-10-22T12:00:00+09:00")!
  }

  func festivalListFixture(_ scenario: FestivalListScenario) throws -> FestivalFeature.State {
    var state = FestivalFeature.State()
    state.viewState = .loaded
    state.hasFinishedFirstCatalogRefresh = true
    state.catalog = IdentifiedArray(uniqueElements: festivalListCatalog)
    state.imageURLs = try festivalListPosterURLs()
    switch scenario {
    case .all:
      break
    case .booked:
      state.listInteraction.selectedFilter = .booked
      state.bookedFestivalIDs = Set(festivalListCatalog.map(\.id))
      state.cachedPacks["busan"] = CachedFestivalPack(
        festivalID: "busan",
        packVersion: 1,
        etag: "visual",
        pack: Data()
      )
      state.packDownloads["seoul-park"] = .downloading(PackDownloadProgress(
        receivedBytes: 62,
        totalBytes: 100
      ))
    case .bookmarkToast:
      state.bookedFestivalIDs = ["busan"]
      state.toast = .bookmarked
    case .searchResult:
      state.listInteraction.isSearching = true
      state.listInteraction.query = "원더"
    case .searchEmpty:
      state.listInteraction.isSearching = true
      state.listInteraction.query = "락페"
    case .searchRecent:
      state.listInteraction.isSearching = true
      state.recentSearches = ["펜타포트", "원더리벳", "삼보마스터", "부산국제록", "XMF"]
    }
    return state
  }

  var festivalListCatalog: [FestivalCatalogItem] {
    return [
      FestivalCatalogItem(
        id: "busan",
        name: "부산국제록페스티벌 2026",
        venue: "부산 삼락생태공원",
        firstDate: "2026-10-24",
        lastDate: "2026-10-25",
        thumbnailURL: URL(string: "https://visual.festicore/busan.png"),
        packVersion: 1,
        status: "upcoming"
      ),
      FestivalCatalogItem(
        id: "wonder",
        name: "원더리벳 2026",
        venue: "고양 킨텍스 제2전시장",
        firstDate: "2026-11-20",
        lastDate: "2026-11-22",
        thumbnailURL: URL(string: "https://visual.festicore/wonder.png"),
        packVersion: 1,
        status: "upcoming"
      ),
      FestivalCatalogItem(
        id: "seoul-park",
        name: "서울 파크 뮤직 페스티벌",
        venue: "서울 올림픽공원 88잔디마당",
        firstDate: "2026-12-19",
        lastDate: "2026-12-20",
        thumbnailURL: URL(string: "https://visual.festicore/seoul-park.png"),
        packVersion: 1,
        status: "upcoming"
      ),
      FestivalCatalogItem(
        id: "pentaport",
        name: "펜타포트 락 페스티벌 2027",
        venue: "인천 송도달빛축제공원",
        packVersion: 0,
        status: "discovered"
      ),
      FestivalCatalogItem(
        id: "xmf",
        name: "XMF 2026",
        venue: "인천 파라다이스시티 컬처파크",
        firstDate: "2026-10-03",
        lastDate: "2026-10-04",
        thumbnailURL: URL(string: "https://visual.festicore/xmf.png"),
        packVersion: 1,
        status: "ended"
      ),
    ]
  }

  /// 시안 S00 전체 프레임의 카드 사진 영역(17, y, 359×140)을 잘라 실제 포스터 대신 쓴다.
  func festivalListPosterURLs() throws -> [String: URL] {
    let frameURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("../../../../DesignExports/S00-S05-20261104/S00/S00 페스티벌 목록 - 전체 (Dark).png")
      .standardizedFileURL
    let frame = try XCTUnwrap(UIImage(contentsOfFile: frameURL.path)?.cgImage)
    let posters: [(id: String, top: CGFloat)] = [
      (
        "busan",
        258
      ),
      (
        "wonder",
        557
      ),
      (
        "seoul-park",
        856
      ),
      (
        "xmf",
        1454
      ),
    ]
    var urls: [String: URL] = [:]
    for poster in posters {
      let image = try XCTUnwrap(frame.cropping(to: CGRect(
        x: 17,
        y: poster.top,
        width: 359,
        height: 140
      )))
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("S00-\(poster.id).png")
      try XCTUnwrap(UIImage(cgImage: image).pngData()).write(to: url)
      urls["https://visual.festicore/\(poster.id).png"] = url
    }
    return urls
  }
}
