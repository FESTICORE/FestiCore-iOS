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
    var canRecoverInitialCredential: Bool
    var revision = UUID()
    var onPersistenceFailure: (@Sendable () -> Void)?
  }

  init(base: any CredentialStore, recoverInitialCredential: Bool = false) {
    self.base = base
    state = OSAllocatedUnfairLock(initialState: State(
      isBarred: base.load() == nil,
      canRecoverInitialCredential: recoverInitialCredential
    ))
  }

  func load() -> FestiCoreCredential? {
    state.withLock { state in
      if state.isBarred {
        guard state.canRecoverInitialCredential, let restored = base.load() else { return nil }
        state.isBarred = false
        state.canRecoverInitialCredential = false
        return restored
      }
      return base.load()
    }
  }

  @discardableResult
  func save(_ credential: FestiCoreCredential) -> Bool {
    state.withLock { state in
      guard !state.isBarred else { return false }
      state.canRecoverInitialCredential = false
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

  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) throws -> Bool {
    try state.withLock { state in
      guard !state.isBarred, state.revision == revision, base.load() == current else { return false }
      let saved = base.save(credential)
      if !saved {
        state.isBarred = true
        state.canRecoverInitialCredential = false
        // 이전 토큰 삭제를 시도하고 저장 실패를 호출자에게 전달한다.
        _ = base.clear()
        state.onPersistenceFailure?()
        state.revision = UUID()
        throw CredentialStoreError.persistenceFailed
      }
      state.revision = UUID()
      return saved
    }
  }

  @discardableResult
  func clear() -> Bool {
    state.withLock { state in
      state.isBarred = true
      state.canRecoverInitialCredential = false
      state.revision = UUID()
      return base.clear()
    }
  }

  func allowSaves() {
    state.withLock { state in
      state.isBarred = false
      state.canRecoverInitialCredential = false
      state.revision = UUID()
    }
  }

  func setPersistenceFailureHandler(_ handler: @escaping @Sendable () -> Void) {
    state.withLock { $0.onPersistenceFailure = handler }
  }
}
