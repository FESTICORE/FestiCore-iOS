import ComposableArchitecture
import FestiCoreDesignKit
import FestivalDomain
import SwiftUI
import XCTest
@testable import Festival

/// 팩 받는 중 진행 표시(#339)를 목록 카드와 라이브 보드에 고정 상태로 렌더한다. 시각 자료 생성용이다.
extension FestivalS01VisualCaptureTests {
  func testCapturePackDownloadProgress() async throws {
    var state = try fixture(.basic)
    let festivalID = try XCTUnwrap(state.selectedFestivalID)
    state.packDownloads[festivalID] = .downloading(.init(
      receivedBytes: 62,
      totalBytes: 100
    ))
    let store = Store(initialState: state) {
      EmptyReducer<FestivalFeature.State, FestivalFeature.Action>()
    } withDependencies: {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    }
    try await capture(
      FestivalLiveBoardRouteView(store: store),
      name: "S01-pack-downloading"
    )
    try await capture(
      VStack(spacing: FestiCoreSpacing.paddingP16) {
        FCPackDownloadProgress("팩 받는 중 · 62%")
          .progress(0.62)
        FCPackDownloadProgress("팩 받는 중")
      }
      .padding(FestiCoreSpacing.paddingP16)
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: .top
      )
      .background(FestiCoreSemanticColor.backgroundElevated.color),
      name: "S00-pack-download-progress",
      size: CGSize(
        width: 393,
        height: 200
      )
    )
  }
}
