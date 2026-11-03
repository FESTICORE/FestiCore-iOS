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

    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear))
    await store.receive(\.inner.loaded) {
      $0.isLoading = false
      $0.board = board
      $0.festival = BearerFestival(id: "fst_1", name: nil, zones: zones)
      $0.lastSyncedAt = now
      $0.current = BearerBoardFeature.Current(board.status)
      $0.lastActivity = .slam
    }
    #expect(store.state.zoneName(for: "zone_a") == "리벳 스테이지 앞 왼쪽")
    // 대기열 이벤트 구독은 화면이 떠 있는 동안 계속된다.
    await store.skipInFlightEffects()
  }

  @Test("쉬는 중을 누르면 바로 바꾸고 1초 체크를 보인 뒤 대기열에 넣는다")
  func rest() async {
    let clock = TestClock()
    let queued = LockIsolated<[BearerStatusRequest]>([])
    let store = TestStore(initialState: loaded(board(.active))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = clock
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), enqueueStatus: { flagID, request in
        #expect(flagID == "flg_1")
        queued.withValue { $0.append(request) }
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
    await store.receive(\.async.enqueue)
    #expect(queued.value == [request])
    await clock.advance(by: .seconds(1))
    await store.receive(\.inner.checkExpired) { $0.check = nil }
  }

  @Test("대기열에 두 건이 쌓여 있으면 서버 상태 위에 차례로 얹어 보이고, 모두 보내면 서버 상태로 맞춘다")
  func twoPendingChanges() async {
    let (events, continuation) = AsyncStream.makeStream(of: BearerOutboxEvent.self)
    let retried = LockIsolated(0)
    let pending = [
      BearerStatusRequest(change: .move(zoneID: "zone_b"), idempotencyKey: "key-1", clientAt: now),
      BearerStatusRequest(change: .rest, idempotencyKey: "key-2", clientAt: now.addingTimeInterval(1))
    ]
    let active = board(.active)
    let store = TestStore(initialState: loaded(active)) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.bearerUseCase = BearerUseCaseStub(
        pendingStatus: { _ in pending },
        statusEvents: { _ in events },
        retryPendingStatus: { retried.withValue { $0 += 1 } }
      )
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear))
    await store.receive(\.inner.pendingLoaded) { $0.pending = pending }
    #expect(store.state.current?.zoneID == "zone_b")
    #expect(store.state.current?.lifecycle == .resting)
    // 서버 상태를 다시 읽어도 보내지 못한 두 변경을 다시 얹는다.
    await store.send(.inner(.loaded(active, nil)))
    #expect(store.state.current?.zoneID == "zone_b")
    #expect(store.state.current?.lifecycle == .resting)

    let resting = BearerFlagStatus(flagID: "flg_1", lifecycle: .resting, zoneID: "zone_b", activity: nil, updatedAt: now)
    continuation.yield(.pending([pending[1]]))
    continuation.yield(.sent(id: "key-1", resting))
    await store.receive(\.inner.outbox) { $0.pending = [pending[1]] }
    #expect(retried.value == 1)
    await store.receive(\.inner.outbox)
    #expect(store.state.current?.lifecycle == .resting)
    continuation.yield(.pending([]))
    continuation.yield(.sent(id: "key-2", resting))
    await store.receive(\.inner.outbox) { $0.pending = [] }
    await store.receive(\.inner.outbox) { $0.current = BearerBoardFeature.Current(resting) }
    continuation.finish()
  }

  @Test("오프라인·로그인 필요·재시도 한도는 알리고, 다시 보내기를 누르면 대기열을 다시 시작한다")
  func outboxStates() async {
    let retried = LockIsolated(0)
    let store = TestStore(initialState: loaded(board(.active))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(retryPendingStatus: { retried.withValue { $0 += 1 } })
    }

    await store.send(.inner(.outbox(.offline))) { $0.isOffline = true }
    await store.send(.inner(.outbox(.needsLogin))) {
      $0.isSendPaused = true
      $0.errorMessage = "로그인이 풀렸어요. 다시 로그인하면 이어서 보내요"
    }
    await store.send(.view(.retrySendTapped)) {
      $0.isSendPaused = false
      $0.errorMessage = nil
    }
    await store.receive(\.async.retrySend)
    #expect(retried.value == 1)
    await store.send(.inner(.outbox(.gaveUp(.unavailable)))) {
      $0.isSendPaused = true
      $0.errorMessage = "서버에 보내지 못했어요. 잠시 뒤 다시 보내기를 눌러 주세요"
    }
  }

  @Test("서버가 받지 않으면(409) 최신 상태를 다시 읽는다")
  func rejectedReloads() async {
    let latest = board(.active, activity: .sing)
    let store = TestStore(initialState: loaded(board(.active))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.bearerUseCase = BearerUseCaseStub(
        fetchFestival: { _ in BearerFestival(id: "fst_1", name: nil, zones: zones) },
        fetchBoard: { _ in latest }
      )
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.inner(.outbox(.rejected(.stale)))) {
      $0.errorMessage = "다른 기기에서 먼저 바뀌어 최신 상태로 돌렸어요"
    }
    await store.receive(\.inner.loaded) {
      $0.current = BearerBoardFeature.Current(latest.status)
      $0.lastActivity = .sing
    }
  }

  @Test("못 보낸 변경이 있으면 닫기 전에 확인을 받는다")
  func closeWithPending() async {
    var state = loaded(board(.active))
    state.pending = [BearerStatusRequest(change: .rest, idempotencyKey: "key-1", clientAt: now)]
    let store = TestStore(initialState: state) { BearerBoardFeature() }

    await store.send(.view(.closeTapped)) { $0.destination = .closeConfirm(.bearerClosePending(count: 1)) }
    await store.send(.destination(.presented(.closeConfirm(.confirmTapped)))) { $0.destination = nil }
    await store.receive(.delegate(.closeRequested))

    let empty = TestStore(initialState: loaded(board(.active))) { BearerBoardFeature() }
    await empty.send(.view(.closeTapped))
    await empty.receive(.delegate(.closeRequested))
  }

  @Test("시작 전에는 존과 활동을 차례로 골라 깃발을 올린다")
  func raise() async {
    let store = TestStore(initialState: loaded(board(.scheduled))) {
      BearerBoardFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.continuousClock = TestClock()
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), enqueueStatus: { _, _ in })
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.raiseTapped)) {
      $0.sheet = .startZone
      $0.destination = .zonePicker(.init(zones: zones, selectedZoneID: "zone_a"))
    }
    await store.send(.destination(.presented(.zonePicker(.delegate(.picked("zone_a")))))) {
      $0.sheet = .startActivity(zoneID: "zone_a")
      $0.destination = .activityPicker(.init(selected: nil))
    }
    await store.send(.destination(.presented(.activityPicker(.delegate(.picked(.sing)))))) {
      $0.destination = nil
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
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), enqueueStatus: { _, _ in })
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.endTapped)) { $0.destination = .alert(.bearerEndToday()) }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
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
      $0.bearerUseCase = BearerUseCaseStub(makeStatusRequest: requests(), enqueueStatus: { _, _ in })
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
