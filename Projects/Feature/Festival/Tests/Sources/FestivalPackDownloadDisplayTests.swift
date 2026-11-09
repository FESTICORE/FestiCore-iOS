//
//  FestivalPackDownloadDisplayTests.swift
//  FestivalTests
//
//  Created by FestiCore on 11/9/26.
//

import FestiCorePackInterface
import Foundation
import Testing
@testable import Festival

/// 팩 받는 중 진행 표시(#339). UseCase가 알린 받은 바이트로 진행 바와 퍼센트를 만든다.
@MainActor
struct FestivalPackDownloadDisplayTests {
  @Test("받은 바이트 비율을 진행 바와 반올림한 퍼센트로 보인다")
  func measuredProgress() {
    let display = state(.downloading(.init(
      receivedBytes: 62,
      totalBytes: 100
    ))).packDownloadDisplay(for: "festival")

    #expect(display == FestivalPackDownloadDisplay(
      progress: 0.62,
      text: "팩 받는 중 · 62%"
    ))
    #expect(state(.downloading(.init(
      receivedBytes: 1,
      totalBytes: 3
    ))).packDownloadDisplay(for: "festival")?.text == "팩 받는 중 · 33%")
  }

  @Test("전체 크기를 모르거나 아직 진행 이벤트가 없으면 진행 바 없이 받는 중만 보인다")
  func unknownProgress() {
    let expected = FestivalPackDownloadDisplay(
      progress: nil,
      text: "팩 받는 중"
    )
    #expect(state(.downloading(nil)).packDownloadDisplay(for: "festival") == expected)
    #expect(state(.downloading(.init(
      receivedBytes: 10,
      totalBytes: 0
    ))).packDownloadDisplay(for: "festival") == expected)
  }

  @Test("받은 바이트가 전체를 넘어도 100%를 넘지 않는다")
  func clampsOverflow() {
    #expect(state(.downloading(.init(
      receivedBytes: 120,
      totalBytes: 100
    ))).packDownloadDisplay(for: "festival") == FestivalPackDownloadDisplay(
      progress: 1,
      text: "팩 받는 중 · 100%"
    ))
  }

  @Test("받는 중이 아닌 축제와 선택이 없는 화면에는 진행 표시가 없다")
  func notDownloading() {
    let downloading = state(.downloading(nil))
    #expect(downloading.packDownloadDisplay(for: "other") == nil)
    #expect(downloading.packDownloadDisplay(for: nil) == nil)
    #expect(FestivalFeature.State().packDownloadDisplay(for: "festival") == nil)
  }

  @Test("라이브 보드는 선택한 축제의 팩을 받는 중일 때만 진행 표시를 가진다")
  func liveBoardShowsSelectedFestivalOnly() {
    var selected = state(.downloading(.init(
      receivedBytes: 45,
      totalBytes: 100
    )))
    selected.selectedFestivalID = "festival"
    #expect(FestivalLiveBoardScreenModel(state: selected).packDownload?.text == "팩 받는 중 · 45%")

    selected.selectedFestivalID = "other"
    #expect(FestivalLiveBoardScreenModel(state: selected).packDownload == nil)
  }

  private func state(_ status: FestivalFeature.PackDownloadStatus) -> FestivalFeature.State {
    var state = FestivalFeature.State()
    state.packDownloads["festival"] = status
    return state
  }
}
