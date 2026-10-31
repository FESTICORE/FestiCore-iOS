//
//  AuthSessionExpiryClient+Live.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreAuthInterface
import Foundation

public extension AuthSessionExpiryClient {
  /// `festiCoreAuthSessionDidExpire` 알림을 구독하고, 스트림이 끝나면 관찰자를 해제한다.
  static func live(notificationCenter: NotificationCenter = .default) -> Self {
    Self(events: {
      AsyncStream { continuation in
        let observer = SendableObserver(notificationCenter.addObserver(
          forName: .festiCoreAuthSessionDidExpire,
          object: nil,
          queue: nil
        ) { _ in
          continuation.yield(())
        })
        continuation.onTermination = { _ in
          notificationCenter.removeObserver(observer.token)
        }
      }
    })
  }
}

private struct SendableObserver: @unchecked Sendable {
  let token: NSObjectProtocol

  init(_ token: NSObjectProtocol) {
    self.token = token
  }
}
