//
//  FestivalPrepGuideTests.swift
//  FestivalTests
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

/// 준비 안내(S15): 처음 받은 팩에서 열고, 2단계(깃발 팔로우)는 단계 이동만 부모에게 맡긴다.
@MainActor
struct FestivalPrepGuideTests {
  private let pack = CachedFestivalPack(
    festivalID: "festival",
    packVersion: 1,
    etag: "v1",
    pack: Data(#"{"id":"festival","name":"원더리벳 2026"}"#.utf8)
  )

  private func downloadingState(
    hasSession: Bool,
    cached: Bool
  ) -> FestivalFeature.State {
    var state = FestivalFeature.State()
    state.hasSession = hasSession
    state.packDownloads["festival"] = .downloading(nil)
    if cached {
      state.cachedPacks["festival"] = pack
    }
    return state
  }

  @Test("로그인한 사용자가 팩을 처음 받으면 준비 안내를 요청한다")
  func firstPackRequestsGuide() async {
    let store = TestStore(initialState: downloadingState(
      hasSession: true,
      cached: false
    )) {
      FestivalFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
    }

    await store.send(.inner(.packDownloadFinished(
      "festival",
      generation: 0,
      .updated(pack)
    ))) {
      $0.packDownloads = [:]
      $0.cachedPacks["festival"] = pack
    }
    await store.receive(.delegate(.prepGuideRequested(festivalID: "festival")))
  }

  @Test("팩 업데이트나 로그인 전 받기에서는 준비 안내를 열지 않는다")
  func updateOrGuestDoesNotRequestGuide() async {
    let update = TestStore(initialState: downloadingState(
      hasSession: true,
      cached: true
    )) {
      FestivalFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
    }
    await update.send(.inner(.packDownloadFinished(
      "festival",
      generation: 0,
      .updated(pack)
    ))) {
      $0.packDownloads = [:]
    }

    let guest = TestStore(initialState: downloadingState(
      hasSession: false,
      cached: false
    )) {
      FestivalFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
    }
    await guest.send(.inner(.packDownloadFinished(
      "festival",
      generation: 0,
      .updated(pack)
    ))) {
      $0.packDownloads = [:]
      $0.cachedPacks["festival"] = pack
    }
  }

  @Test("깃발 단계의 다음·건너뛰기는 끝, 나중에는 안내 전체를 미룬다")
  func flagsStepDelegates() async {
    let store = TestStore(initialState: FestivalPrepFlagsFeature.State(festivalID: "festival")) {
      FestivalPrepFlagsFeature()
    }

    await store.send(.view(.nextTapped))
    await store.receive(.delegate(.finished))
    await store.send(.view(.skipTapped))
    await store.receive(.delegate(.finished))
    await store.send(.view(.laterTapped))
    await store.receive(.delegate(.later))
  }

  @Test("깃발 팔로우에 로그인이 필요하면 부모에게 로그인을 요청한다")
  func flagsStepLogin() async {
    let store = TestStore(initialState: FestivalPrepFlagsFeature.State(festivalID: "festival")) {
      FestivalPrepFlagsFeature()
    }

    await store.send(.flag(.directory(.delegate(.loginRequested))))
    await store.receive(.delegate(.loginRequested))
  }

  @Test("성향 칩과 관계없이 팔로우 중인 깃발 수를 센다")
  func followingCountIgnoresTag() {
    var state = FestivalPrepFlagsFeature.State(festivalID: "festival")
    #expect(state.followingCount == 0)
    state.flag.snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival",
      activeFlags: [],
      followedFlags: [FestivalLiveBoardSnapshot.Flag(
        id: "flg_1",
        name: "호락호락",
        status: "scheduled",
        zoneID: nil,
        activity: nil,
        thumbnailURL: nil,
        tags: ["slam"]
      )],
      crew: nil,
      directoryFlags: [
        FestivalLiveBoardSnapshot.Flag(
          id: "flg_1",
          name: "호락호락",
          status: "scheduled",
          zoneID: nil,
          activity: nil,
          thumbnailURL: nil,
          tags: ["slam"]
        ),
        FestivalLiveBoardSnapshot.Flag(
          id: "flg_2",
          name: "떼창단",
          status: "scheduled",
          zoneID: nil,
          activity: nil,
          thumbnailURL: nil,
          tags: ["sing"]
        ),
      ]
    )
    state.flag.directory.tag = .sing
    #expect(state.followingCount == 1)
  }
}
