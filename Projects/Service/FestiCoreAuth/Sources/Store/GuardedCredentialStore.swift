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
    var sessionID = UUID()
  }

  init(base: any CredentialStore) {
    self.base = base
    state = OSAllocatedUnfairLock(initialState: State(isBarred: base.load() == nil))
  }

  func load() -> FestiCoreCredential? {
    state.withLock { _ in base.load() }
  }

  var sessionID: UUID { state.withLock { $0.sessionID } }

  func sessionSnapshot() -> FestiCoreCredentialSession? {
    state.withLock { state in
      guard !state.isBarred, let credential = base.load() else { return nil }
      return FestiCoreCredentialSession(credential: credential, id: state.sessionID)
    }
  }

  func startSession(_ credential: FestiCoreCredential) {
    state.withLock { state in
      state.sessionID = UUID()
      state.revision = UUID()
      state.isBarred = false
      base.save(credential)
    }
  }

  func save(_ credential: FestiCoreCredential) {
    state.withLock { state in
      guard !state.isBarred else { return }
      base.save(credential)
      state.revision = UUID()
    }
  }

  func revision(matching current: FestiCoreCredential) -> UUID? {
    state.withLock { state in
      guard !state.isBarred, base.load() == current else { return nil }
      return state.revision
    }
  }

  func refreshContext(matching current: FestiCoreCredential) -> FestiCoreRefreshContext? {
    state.withLock { state in
      guard !state.isBarred, base.load() == current else { return nil }
      return FestiCoreRefreshContext(sessionID: state.sessionID, revision: state.revision)
    }
  }

  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) -> Bool {
    state.withLock { state in
      guard !state.isBarred, state.revision == revision, base.load() == current else { return false }
      base.save(credential)
      state.revision = UUID()
      return true
    }
  }

  func clear() {
    state.withLock { state in
      state.isBarred = true
      state.revision = UUID()
      state.sessionID = UUID()
      base.clear()
    }
  }

  func allowSaves() {
    state.withLock { state in
      state.isBarred = false
      state.revision = UUID()
      state.sessionID = UUID()
    }
  }
}
