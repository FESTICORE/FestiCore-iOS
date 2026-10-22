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
  private let isBarred: OSAllocatedUnfairLock<Bool>

  init(base: any CredentialStore) {
    self.base = base
    isBarred = OSAllocatedUnfairLock(initialState: base.load() == nil)
  }

  func load() -> FestiCoreCredential? {
    isBarred.withLock { _ in base.load() }
  }

  func save(_ credential: FestiCoreCredential) {
    isBarred.withLock { barred in
      guard !barred else { return }
      base.save(credential)
    }
  }

  func clear() {
    isBarred.withLock { barred in
      barred = true
      base.clear()
    }
  }

  func allowSaves() {
    isBarred.withLock { $0 = false }
  }
}
