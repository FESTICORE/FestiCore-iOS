//
//  AuthSessionExpiryClientTests.swift
//  FestiCoreAuthTests
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreAuthInterface
import Foundation
import Testing
@testable import FestiCoreAuth

@Suite("인증 만료 알림")
struct AuthSessionExpiryClientTests {
  @Test("만료 알림이 게시될 때마다 이벤트를 보낸다")
  func deliversPostedExpiry() async {
    let center = NotificationCenter()
    let client = AuthSessionExpiryClient.live(notificationCenter: center)
    var iterator = client.events().makeAsyncIterator()

    center.post(name: .festiCoreAuthSessionDidExpire, object: nil)
    center.post(name: .festiCoreAuthSessionDidExpire, object: nil)

    #expect(await iterator.next() != nil)
    #expect(await iterator.next() != nil)
  }

  @Test("테스트 기본값은 미등록 이슈를 보고하고 이벤트 없이 끝난다")
  func testValueReportsUnregisteredAndFinishes() async {
    await withKnownIssue {
      var iterator = AuthSessionExpiryDependency.testValue.events().makeAsyncIterator()
      #expect(await iterator.next() == nil)
    }
  }

  @Test("구독이 끝나면 관찰자를 해제한다")
  func removesObserverWhenStreamEnds() async {
    let center = RecordingNotificationCenter()
    let stream = AuthSessionExpiryClient.live(notificationCenter: center).events()
    let task = Task { for await _ in stream {} }

    task.cancel()
    await task.value

    #expect(center.removedCount == 1)
  }
}

private final class RecordingNotificationCenter: NotificationCenter, @unchecked Sendable {
  private let lock = NSLock()
  private var removed = 0

  var removedCount: Int { lock.withLock { removed } }

  override func removeObserver(_ observer: Any) {
    lock.withLock { removed += 1 }
    super.removeObserver(observer)
  }
}
