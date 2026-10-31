//
//  GuardedCredentialStore.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import os
import FestiCoreNetworkInterface

/// 로그아웃 뒤 늦게 도착한 refresh 저장을 차단한다.
final class GuardedCredentialStore: CredentialStore {
  private let base: any CredentialStore
  private let state: OSAllocatedUnfairLock<State>

  private struct State {
    var isBarred: Bool
    var revision = UUID()
    var onPersistenceFailure: (@Sendable () -> Void)?
  }

  init(base: any CredentialStore) {
    self.base = base
    state = OSAllocatedUnfairLock(initialState: State(isBarred: base.load() == nil))
  }

  func load() -> FestiCoreCredential? {
    state.withLock { state in state.isBarred ? nil : base.load() }
  }

  @discardableResult
  func save(_ credential: FestiCoreCredential) -> Bool {
    state.withLock { state in
      guard !state.isBarred else { return false }
      let saved = base.save(credential)
      if !saved { state.isBarred = true }
      state.revision = UUID()
      return saved
    }
  }

  func revision(matching current: FestiCoreCredential) -> UUID? {
    state.withLock { state in
      guard !state.isBarred, base.load() == current else { return nil }
      return state.revision
    }
  }

  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) -> Bool {
    state.withLock { state in
      guard !state.isBarred, state.revision == revision, base.load() == current else { return false }
      let saved = base.save(credential)
      if !saved {
        state.isBarred = true
        // 무결성 값 첫 쓰기가 실패해도 이전 토큰 쌍이 다음 실행에서 복원되지 않게 한다.
        base.clear()
        state.onPersistenceFailure?()
      }
      state.revision = UUID()
      return saved
    }
  }

  func clear() {
    state.withLock { state in
      state.isBarred = true
      state.revision = UUID()
      base.clear()
    }
  }

  func allowSaves() {
    state.withLock { state in
      state.isBarred = false
      state.revision = UUID()
    }
  }

  func setPersistenceFailureHandler(_ handler: @escaping @Sendable () -> Void) {
    state.withLock { $0.onPersistenceFailure = handler }
  }
}
