//
//  BearerBoardFeatureTests.swift
//  BearerTests
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import Testing
@testable import Bearer

@MainActor
struct BearerBoardFeatureTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let zones = [BearerZone(id: "zone_a", name: "리벳 스테이지 앞 왼쪽"), BearerZone(id: "zone_b", name: "리벳 스테이지 중앙")]

  private func board(_ lifecycle: BearerFlagLifecycle, activity: BearerActivity? = .slam, restartUsedToday: Bool = false, updatedBy: BearerCoBearer? = nil) -> BearerBoard {
    BearerBoard(
      profile: BearerFlagProfile(id: "flg_1", name: "호락호락", homeZoneID: "zone_a"),
      status: BearerFlagStatus(
        flagID: "flg_1", lifecycle: lifecycle, zoneID: lifecycle == .active || lifecycle == .resting ? "zone_a" : nil,
        activity: lifecycle == .active ? activity : nil, updatedAt: now, updatedBy: updatedBy
      ),
      followerCount: 1284,
      restartUsedToday: restartUsedToday
    )
  }

  private func loaded(_ board: BearerBoard, viewer: String? = "usr_me") -> BearerBoardFeature.State {
    var state = BearerBoardFeature.State(festivalID: "fst_1", flagID: "flg_1", viewerUserID: viewer)
    state.board = board
    state.festival = BearerFestival(id: "fst_1", name: "원더리벳 2026", zones: zones)
    state.current = BearerBoardFeature.Current(board.status)
    state.lastActivity = board.status.activity
    return state
  }

  /// 호출할 때마다 key-1, key-2 … 를 주는 상태 요청 생성기
  private func requests() -> @Sendable (BearerStatusChange) -> BearerStatusRequest {
    let counter = LockIsolated(0)
    let now = now
    return { change in
      counter.withValue { $0 += 1 }
      return BearerStatusRequest(change: change, idempotencyKey: "key-\(counter.value)", clientAt: now)
    }
  }

  @Test("기수 보드를 열면 상태·존·팔로워 수를 읽는다")
  func loads() async {
    let board = board(.active)
    let store = TestStore(initialState: BearerBoardFeature.State(festivalID: "fst_1", flagID: "flg_1", viewerUserID: "usr_me")) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.bearerUseCase = BearerUseCaseStub(
        fetchFestival: { _ in BearerFestival(id: "fst_1", name: nil, zones: zones) },
        fetchBoard: { _ in board }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load) { $0.isLoading = true }
    await store.receive(\.inner.loaded) {
      $0.isLoading = false
      $0.board = board
      $0.festival = BearerFestival(id: "fst_1", name: nil, zones: zones)
      $0.lastSyncedAt = now
      $0.current = BearerBoardFeature.Current(board.status)
      $0.lastActivity = .slam
    }
    #expect(store.state.zoneName(for: "zone_a") == "리벳 스테이지 앞 왼쪽")
  }

  @Test("쉬는 중을 누르면 바로 바꾸고 1초 체크를 보인 뒤 보낸다")
  func rest() async {
    let clock = TestClock()
    let sent = LockIsolated<[BearerStatusRequest]>([])
    let resting = BearerFlagStatus(flagID: "flg_1", lifecycle: .resting, zoneID: "zone_a", activity: nil, updatedAt: now)
    let store = TestStore(initialState: loaded(board(.active))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = clock
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), sendStatus: { _, request in
        sent.withValue { $0.append(request) }
        return resting
      })
    }

    let request = BearerStatusRequest(change: .rest, idempotencyKey: "key-1", clientAt: now)
    await store.send(.view(.restTapped)) {
      $0.pending = [request]
      $0.current?.lifecycle = .resting
      $0.current?.activity = nil
      $0.checkSequence = 1
      $0.check = .init(id: 1, title: "쉬는 중으로 바뀌었어요", message: "팔로워에게 알렸어요")
    }
    await store.receive(\.async.expireCheck)
    await store.receive(\.async.flush) { $0.isSending = true }
    await store.receive(\.inner.sent) {
      $0.isSending = false
      $0.pending = []
      $0.lastSyncedAt = now
      $0.current = BearerBoardFeature.Current(resting)
    }
    #expect(sent.value == [request])
    await clock.advance(by: .seconds(1))
    await store.receive(\.inner.checkExpired) { $0.check = nil }
  }

  @Test("오프라인이면 대기열에 두고 같은 멱등키로 다시 보낸다")
  func offlineQueue() async {
    let clock = TestClock()
    let attempts = LockIsolated<[String]>([])
    let moved = BearerFlagStatus(flagID: "flg_1", lifecycle: .active, zoneID: "zone_b", activity: .slam, updatedAt: now)
    let store = TestStore(initialState: loaded(board(.active))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = clock
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), sendStatus: { _, request in
        attempts.withValue { $0.append(request.idempotencyKey) }
        if attempts.value.count == 1 { throw BearerError.offline }
        return moved
      })
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.zoneTapped)) {
      $0.sheet = .move
      $0.zonePicker = .init(zones: zones, selectedZoneID: "zone_a")
    }
    await store.send(.scope(.zonePicker(.presented(.view(.zoneTapped("zone_b"))))))
    await store.receive(\.scope.zonePicker.presented.delegate.picked) {
      $0.zonePicker = nil
      $0.sheet = nil
      $0.current?.zoneID = "zone_b"
      $0.check = .init(id: 1, title: "리벳 스테이지 중앙으로 바뀌었어요", message: "팔로워에게 알렸어요")
    }
    await store.receive(\.inner.sendFailed) {
      $0.isOffline = true
      $0.pending = [BearerStatusRequest(change: .move(zoneID: "zone_b"), idempotencyKey: "key-1", clientAt: now)]
    }
    #expect(store.state.current?.zoneID == "zone_b")

    await clock.advance(by: .seconds(5))
    await store.receive(\.inner.retryFired)
    await store.receive(\.inner.sent) {
      $0.isOffline = false
      $0.pending = []
      $0.current = BearerBoardFeature.Current(moved)
    }
    #expect(attempts.value == ["key-1", "key-1"])
  }

  @Test("다른 기기가 먼저 바꿨으면(409) 대기열을 비우고 최신 상태를 다시 읽는다")
  func staleReloads() async {
    let latest = board(.active, activity: .sing)
    var state = loaded(board(.active))
    state.pending = [
      BearerStatusRequest(change: .rest, idempotencyKey: "key-1", clientAt: now),
      BearerStatusRequest(change: .end, idempotencyKey: "key-2", clientAt: now)
    ]
    state.isSending = true
    let store = TestStore(initialState: state) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.bearerUseCase = BearerUseCaseStub(
        fetchFestival: { _ in BearerFestival(id: "fst_1", name: nil, zones: zones) },
        fetchBoard: { _ in latest }
      )
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.inner(.sendFailed(id: "key-1", .stale))) {
      $0.isSending = false
      $0.pending = []
      $0.errorMessage = "다른 기기에서 먼저 바뀌어 최신 상태로 돌렸어요"
    }
    await store.receive(\.inner.loaded) {
      $0.current = BearerBoardFeature.Current(latest.status)
      $0.lastActivity = .sing
    }
  }

  @Test("시작 전에는 존과 활동을 차례로 골라 깃발을 올린다")
  func raise() async {
    let store = TestStore(initialState: loaded(board(.scheduled))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = TestClock()
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), sendStatus: { _, _ in throw BearerError.offline })
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.raiseTapped)) {
      $0.sheet = .startZone
      $0.zonePicker = .init(zones: zones, selectedZoneID: "zone_a")
    }
    await store.send(.scope(.zonePicker(.presented(.delegate(.picked("zone_a")))))) {
      $0.zonePicker = nil
      $0.sheet = .startActivity(zoneID: "zone_a")
      $0.activityPicker = .init(selected: nil)
    }
    await store.send(.scope(.activityPicker(.presented(.delegate(.picked(.sing)))))) {
      $0.activityPicker = nil
      $0.sheet = nil
      $0.current?.lifecycle = .active
      $0.current?.zoneID = "zone_a"
      $0.current?.activity = .sing
      $0.lastActivity = .sing
      $0.pending = [BearerStatusRequest(change: .start(zoneID: "zone_a", activity: .sing), idempotencyKey: "key-1", clientAt: now)]
    }
    await store.skipInFlightEffects()
  }

  @Test("종료는 확인 팝업을 거치고, 오늘 재시작을 쓴 뒤에는 다시 시작하지 않는다")
  func endAndRestart() async {
    let store = TestStore(initialState: loaded(board(.active))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = TestClock()
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), sendStatus: { _, _ in throw BearerError.offline })
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.endTapped)) { $0.alert = .bearerEndToday() }
    await store.send(.scope(.alert(.presented(.confirmTapped)))) {
      $0.alert = nil
      $0.current?.lifecycle = .ended
      $0.current?.zoneID = nil
      $0.current?.activity = nil
    }
    #expect(!store.state.restartUsedToday)

    await store.skipInFlightEffects()
    let used = TestStore(initialState: loaded(board(.ended, restartUsedToday: true))) { BearerBoardFeature() }
    #expect(used.state.restartUsedToday)
    await used.send(.view(.restartTapped))
  }

  @Test("쉬는 중에서 다시 시작하면 마지막 활동으로 돌아간다")
  func resume() async {
    var state = loaded(board(.resting))
    state.lastActivity = .train
    let store = TestStore(initialState: state) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = TestClock()
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), sendStatus: { _, _ in throw BearerError.offline })
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.resumeTapped)) {
      $0.current?.lifecycle = .active
      $0.current?.activity = .train
      $0.pending = [BearerStatusRequest(change: .activity(.train), idempotencyKey: "key-1", clientAt: now)]
    }
    await store.skipInFlightEffects()
  }

  @Test("다른 공동 기수가 바꿨을 때만 바꾼 사람을 보인다")
  func coBearerChange() {
    let other = BearerCoBearer(userID: "usr_co", nickname: "민지")
    #expect(loaded(board(.active, updatedBy: other)).changedByOtherBearer == other)
    #expect(loaded(board(.active, updatedBy: BearerCoBearer(userID: "usr_me", nickname: "로이"))).changedByOtherBearer == nil)
    #expect(loaded(board(.active)).changedByOtherBearer == nil)
  }

  @Test("받침에 맞춰 조사를 붙인다")
  func josa() {
    #expect("리벳 스테이지 중앙".withEuro == "리벳 스테이지 중앙으로")
    #expect("슬램 존".withEuro == "슬램 존으로")
    #expect("떼창".withEuro == "떼창으로")
    #expect("기차놀이".withEuro == "기차놀이로")
    #expect("정문".withIga == "정문이")
    #expect("민지".withIga == "민지가")
  }
}
