//
//  AuthSessionExpiryClient.swift
//  FestiCore
//
//  Created by FestiCore on 10/31/26.
//

import Dependencies
import FestiCoreAuthInterface
import Foundation

struct AuthSessionExpiryClient: DependencyKey, Sendable {
  var events: @Sendable () -> AsyncStream<Void>

  static let liveValue = Self(events: {
    AsyncStream { continuation in
      let observer = SendableObserver(NotificationCenter.default.addObserver(
        forName: .festiCoreAuthSessionDidExpire,
        object: nil,
        queue: nil
      ) { _ in
        continuation.yield(())
      })
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer.token)
      }
    }
  })

  static let testValue = Self(events: {
    AsyncStream { $0.finish() }
  })
}

private struct SendableObserver: @unchecked Sendable {
  let token: NSObjectProtocol

  init(_ token: NSObjectProtocol) {
    self.token = token
  }
}

extension DependencyValues {
  var authSessionExpiryClient: AuthSessionExpiryClient {
    get { self[AuthSessionExpiryClient.self] }
    set { self[AuthSessionExpiryClient.self] = newValue }
  }
}
