//
//  SplashFeatureTests.swift
//  FestiCoreTests
//
//  Created by FestiCore on 10/28/26.
//

import Clocks
import ComposableArchitecture
import Testing
@testable import FestiCore

@MainActor
struct SplashFeatureTests {
  @Test func completesOnceAfterTwoSeconds() async {
    let clock = TestClock()
    let store = TestStore(initialState: SplashFeature.State()) {
      SplashFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }

    await store.send(.view(.onAppear)) {
      $0.hasStarted = true
    }
    await store.receive(\.async.waitForAnimation)
    await store.send(.view(.onAppear))

    await clock.advance(by: .seconds(1))
    await clock.advance(by: .seconds(1))

    await store.receive(\.inner.animationFinished) {
      $0.didComplete = true
    }
    await store.receive(\.delegate.presentHome)
    await store.send(.inner(.animationFinished))
  }

  @Test func ignoresCompletionBeforeAppear() async {
    let clock = TestClock()
    let store = TestStore(initialState: SplashFeature.State()) {
      SplashFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }

    await store.send(.inner(.animationFinished))

    await store.send(.view(.onAppear)) {
      $0.hasStarted = true
    }
    await store.receive(\.async.waitForAnimation)
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.animationFinished) {
      $0.didComplete = true
    }
    await store.receive(\.delegate.presentHome)
  }
}
