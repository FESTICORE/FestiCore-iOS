//
//  BearerClaimFeatureTests.swift
//  BearerTests
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import Foundation
import Testing
@testable import Bearer

@MainActor
struct BearerClaimFeatureTests {
  private let now = Date(timeIntervalSince1970: 1_000)

  @Test("코드는 대문자 6자리 허용 글자만 남긴다")
  func filtersCode() async {
    let store = TestStore(initialState: BearerClaimFeature.State(festivalID: "fst_1")) { BearerClaimFeature() }

    await store.send(.view(.codeChanged("r4k-9o1t2xy"))) { $0.code = "R4K9T2" }
    #expect(store.state.canSubmit)
  }

  @Test("맞는 코드는 기수 등록 결과를 부모에게 알린다")
  func claims() async {
    let store = TestStore(initialState: BearerClaimFeature.State(festivalID: "fst_1")) {
      BearerClaimFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.bearerUseCase = BearerUseCaseStub(claim: { festivalID, code in
        #expect(festivalID == "fst_1")
        #expect(code == "R4K9T2")
        return BearerSample.claim
      })
    }

    await store.send(.view(.codeChanged("R4K9T2"))) { $0.code = "R4K9T2" }
    await store.send(.view(.submitTapped)) {
      $0.now = now
      $0.isSubmitting = true
    }
    await store.receive(\.async.claim)
    await store.receive(\.inner.claimSucceeded) { $0.isSubmitting = false }
    await store.receive(.delegate(.claimed(festivalID: "fst_1", claim: BearerSample.claim)))
  }

  @Test("틀린 코드는 남은 횟수를 보이고 서버 값이 없으면 직접 센다")
  func invalidCode() async {
    let store = TestStore(initialState: BearerClaimFeature.State(festivalID: "fst_1")) {
      BearerClaimFeature()
    } withDependencies: {
      $0.date = .constant(now)
      $0.bearerUseCase = BearerUseCaseStub(claim: { _, _ in throw BearerError.invalidCode(remainingAttempts: nil) })
    }

    await store.send(.view(.codeChanged("R4K9T2"))) { $0.code = "R4K9T2" }
    await store.send(.view(.submitTapped)) {
      $0.now = now
      $0.isSubmitting = true
    }
    await store.receive(\.async.claim)
    await store.receive(\.inner.claimFailed) {
      $0.isSubmitting = false
      $0.consecutiveFailures = 1
      $0.failure = .invalid(remainingAttempts: 2)
    }
    await store.send(.view(.codeChanged("R4K9T"))) {
      $0.code = "R4K9T"
      $0.failure = nil
    }
    await store.send(.inner(.claimFailed(.invalidCode(remainingAttempts: 1)))) {
      $0.consecutiveFailures = 2
      $0.failure = .invalid(remainingAttempts: 1)
    }
  }

  @Test("잠기면 입력을 비우고 1초마다 남은 시간을 줄인 뒤 풀어 준다")
  func locked() async {
    let clock = TestClock()
    let current = LockIsolated(now)
    let store = TestStore(initialState: BearerClaimFeature.State(festivalID: "fst_1")) {
      BearerClaimFeature()
    } withDependencies: {
      $0.date = DateGenerator { current.value }
      $0.continuousClock = clock
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.codeChanged("R4K9T2")))
    await store.send(.inner(.claimFailed(.codeLocked(retryAfter: 2)))) {
      $0.code = ""
      $0.failure = .locked
      $0.lockedUntil = now.addingTimeInterval(2)
    }
    #expect(store.state.isLocked)
    #expect(store.state.lockRemainingSeconds == 2)
    await store.send(.view(.codeChanged("ABCDEF")))
    #expect(store.state.code.isEmpty)

    current.setValue(now.addingTimeInterval(1))
    await clock.advance(by: .seconds(1))
    await store.receive(\.inner.lockTicked) { $0.now = now.addingTimeInterval(1) }
    #expect(store.state.lockRemainingSeconds == 1)

    current.setValue(now.addingTimeInterval(2))
    await clock.advance(by: .seconds(1))
    await store.receive(\.inner.lockTicked) {
      $0.now = now.addingTimeInterval(2)
      $0.lockedUntil = nil
      $0.failure = nil
    }
    #expect(!store.state.isLocked)
  }

  @Test("이미 다른 깃발을 맡았으면 안내 문구를 보인다")
  func bearerLimit() async {
    let store = TestStore(initialState: BearerClaimFeature.State(festivalID: "fst_1")) { BearerClaimFeature() }
    await store.send(.inner(.claimFailed(.bearerLimit))) {
      $0.failure = .message("이 페스티벌에서 이미 다른 깃발을 맡고 있어요")
    }
  }

  @Test("뒤로 가기는 닫기를 요청한다")
  func back() async {
    let store = TestStore(initialState: BearerClaimFeature.State(festivalID: "fst_1")) { BearerClaimFeature() }
    await store.send(.view(.backTapped))
    await store.receive(.delegate(.closeRequested))
  }
}
