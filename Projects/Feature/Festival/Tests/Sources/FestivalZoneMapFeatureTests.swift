import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalZoneMapFeatureTests {
  @Test func appearLoadsMapAndLiveBoardThenFlagsChangedMap() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let map = sampleMap(version: "zm-old")
    let snapshot = FestivalLiveBoardSnapshot(
      festivalID: "fst_a",
      activeFlags: [],
      followedFlags: [],
      crew: nil,
      receivedAt: now
    )
    let store = TestStore(initialState: FestivalZoneMapFeature.State(
      festivalID: "fst_a",
      viewerUserID: "user_a",
      selectedZoneID: "zon_a"
    )) {
      FestivalZoneMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.continuousClock = TestClock()
      $0.festivalZoneMapUseCase = MockFestivalZoneMapUseCase(
        cachedMap: { _, _ in map },
        isMapChanged: { $0.version != "zm-new" }
      )
      $0.festivalLiveBoardUseCase = MockFestivalLiveBoardUseCase(liveBoard: { _ in snapshot })
    }
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.mapLoaded) { $0.map = .loaded(map) }
    await store.receive(\.inner.liveLoaded) {
      $0.live.snapshot = snapshot
      $0.live.receivedAt = now
    }
    await store.receive(\.inner.mapVersionChecked) { $0.isMapChanged = true }
    #expect(store.state.selectedZoneID == "zon_a")
    await store.skipInFlightEffects()
  }

  @Test func watchingTheLiveBoardRefreshesPositionsEveryInterval() async {
    let clock = TestClock()
    let calls = LockIsolated(0)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = FestivalLiveBoardSnapshot(
      festivalID: "fst_a",
      activeFlags: [],
      followedFlags: [],
      crew: nil,
      receivedAt: now
    )
    let store = TestStore(initialState: FestivalZoneMapFeature.State(
      festivalID: "fst_a",
      viewerUserID: nil
    )) {
      FestivalZoneMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.continuousClock = clock
      $0.festivalLiveBoardUseCase = MockFestivalLiveBoardUseCase(liveBoard: { _ in
        calls.withValue { $0 += 1 }
        return snapshot
      })
    }

    let watch = await store.send(.async(.watchLive))
    await store.receive(\.inner.liveLoaded) {
      $0.live.snapshot = snapshot
      $0.live.receivedAt = now
    }
    await clock.advance(by: .seconds(FestivalZoneMapFeature.liveRefreshInterval - 1))
    #expect(calls.value == 1)
    await clock.advance(by: .seconds(1))
    await store.receive(\.inner.liveLoaded)
    #expect(calls.value == 2)
    await watch.cancel()
  }

  @Test func tappingZonesTogglesTheCardAndBackgroundClearsIt() async {
    let store = TestStore(initialState: FestivalZoneMapFeature.State(
      festivalID: "fst_a",
      viewerUserID: nil
    )) {
      FestivalZoneMapFeature()
    }
    await store.send(.view(.zoneTapped("zon_a"))) { $0.selectedZoneID = "zon_a" }
    await store.send(.view(.zoneTapped("zon_b"))) { $0.selectedZoneID = "zon_b" }
    await store.send(.view(.zoneTapped("zon_b"))) { $0.selectedZoneID = nil }
    await store.send(.view(.zoneTapped("zon_a"))) { $0.selectedZoneID = "zon_a" }
    await store.send(.view(.mapBackgroundTapped)) { $0.selectedZoneID = nil }
  }

  @Test func liveBoardFailureShowsOfflineAndKeepsLastSnapshot() async {
    let store = TestStore(initialState: FestivalZoneMapFeature.State(
      festivalID: "fst_a",
      viewerUserID: nil
    )) {
      FestivalZoneMapFeature()
    } withDependencies: {
      $0.continuousClock = TestClock()
      $0.festivalLiveBoardUseCase = MockFestivalLiveBoardUseCase(liveBoard: { _ in
        throw FestivalLiveBoardError.invalidResponse
      })
    }
    let watch = await store.send(.async(.watchLive))
    await store.receive(\.inner.liveFailed) { $0.live.isOffline = true }
    await watch.cancel()
  }

  @Test func updatingThePackReloadsTheMapAndClearsTheBanner() async throws {
    let updated = LockIsolated<[String]>([])
    var state = FestivalZoneMapFeature.State(
      festivalID: "fst_a",
      viewerUserID: nil
    )
    state.map = .loaded(sampleMap(version: "zm-old"))
    state.isMapChanged = true
    let store = TestStore(initialState: state) {
      FestivalZoneMapFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(updatePack: { id in
        updated.withValue { $0.append(id) }
        return nil
      })
      $0.festivalZoneMapUseCase = MockFestivalZoneMapUseCase(
        cachedMap: { _, _ in sampleMap(version: "zm-new") },
        isMapChanged: { _ in false }
      )
    }
    store.exhaustivity = .off

    await store.send(.view(.updatePackTapped)) { $0.isUpdatingPack = true }
    await store.receive(\.inner.packUpdated) {
      $0.isUpdatingPack = false
      $0.isMapChanged = false
    }
    await store.receive(\.inner.mapLoaded) { $0.map = .loaded(sampleMap(version: "zm-new")) }
    #expect(updated.value == ["fst_a"])
  }

  @Test func modelPlacesFollowedFlagsCrewAndOtherFlagsAndBuildsTheCard() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let map = sampleMap(version: "zm-1")
    let snapshot = FestivalLiveBoardSnapshot(
      festivalID: "fst_a",
      activeFlags: [
        .init(
          id: "flg_followed",
          name: "호락호락",
          status: "active",
          zoneID: "zon_a",
          activity: "slam",
          thumbnailURL: nil,
          updatedAt: now.addingTimeInterval(-240)
        ),
        .init(
          id: "flg_other",
          name: "빨간바지",
          status: "resting",
          zoneID: "zon_a",
          activity: "calm",
          thumbnailURL: nil,
          updatedAt: now.addingTimeInterval(-60)
        ),
      ],
      followedFlags: [.init(
        id: "flg_followed",
        name: "호락호락",
        status: "active",
        zoneID: "zon_a",
        activity: "slam",
        thumbnailURL: nil
      )],
      crew: .init(
        id: "crew",
        name: "크루",
        members: [
          .init(
            id: "user_a",
            nickname: "로이",
            state: "here",
            zoneID: "zon_a",
            updatedAt: now
          ),
          .init(
            id: "user_b",
            nickname: "한솔",
            state: "leaving",
            zoneID: "zon_b",
            updatedAt: now.addingTimeInterval(-3_600)
          ),
        ]
      )
    )
    let model = FestivalZoneMapModel(
      map: map,
      snapshot: snapshot,
      viewerUserID: "user_a",
      now: now
    )
    #expect(model.markers["zon_a"]?.map(\.id) == ["flg_followed", "user_a", "flg_other"])
    #expect(model.markers["zon_b"]?.first?.isStale == true)
    #expect(model.bottomBanner == nil)
    #expect(model.countText("zon_a") == "깃발 2 · 크루 1")
    #expect(model.countText("zon_c") == "–")

    let card = FestivalZoneMapModel.card(
      zone: map.zones[0],
      map: map,
      snapshot: snapshot,
      viewerUserID: "user_a",
      now: now
    )
    #expect(card.meta == "무대 앞 · 깃발 2 · 크루 1")
    #expect(card.flags.map(\.meta) == ["팔로우 중 · 슬램", "차분"])
    #expect(card.flags.map(\.status) == [.active, .resting])
    #expect(card.crew.first?.isMe == true)

    let empty = FestivalZoneMapModel.card(
      zone: map.zones[2],
      map: map,
      snapshot: snapshot,
      viewerUserID: "user_a",
      now: now
    )
    #expect(empty.isEmpty)
    #expect(empty.meta == "무대 앞 · 지금 아무도 없어요")

    let quiet = FestivalZoneMapModel(
      map: map,
      snapshot: nil,
      viewerUserID: nil,
      now: now
    )
    #expect(quiet.bottomBanner == .followGuide)
  }
}

private func sampleMap(version: String) -> FestivalZoneMap {
  let area = FestivalZoneMap.Area(
    x: 0.1,
    y: 0.1,
    width: 0.4,
    height: 0.2
  )
  return FestivalZoneMap(
    festivalID: "fst_a",
    version: version,
    imageURL: nil,
    aspect: 0.655,
    flagsEnabled: true,
    zones: [
      .init(
        id: "zon_a",
        name: "리벳 스테이지 앞 왼쪽",
        kind: "무대 앞",
        area: area,
        landmark: nil
      ),
      .init(
        id: "zon_b",
        name: "정문",
        kind: "출입구",
        area: area,
        landmark: "GATE"
      ),
      .init(
        id: "zon_c",
        name: "TENT 앞",
        kind: "무대 앞",
        area: area,
        landmark: "TENT 무대"
      ),
    ],
    stageHeaders: []
  )
}
