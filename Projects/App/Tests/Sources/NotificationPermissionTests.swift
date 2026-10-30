import Foundation
import Testing
import UserNotifications

import FestiCoreStorageInterface
@testable import FestiCore

@MainActor
struct NotificationPermissionTests {
  @Test("허용하면 한 번만 권한을 요청하고 APNs 등록을 시작한다")
  func authorizedFlowAndReentry() async {
    let delegate = AppDelegate()
    let state = NotificationPermissionState(status: .notDetermined, requestResult: true)
    delegate.notificationAuthorizationClient = state.client
    delegate.secureStorage = MemoryNotificationStorage()

    #expect(await delegate.requestNotificationPermission() == .authorized)
    #expect(await delegate.requestNotificationPermission() == .authorized)
    #expect(state.requestCount == 1)
    #expect(state.registrationCount == 1)
  }

  @Test("알림 표시를 거부해도 APNs 등록과 기존 토큰은 유지한다")
  func deniedFlowAndReentry() async {
    let delegate = AppDelegate()
    let state = NotificationPermissionState(status: .notDetermined, requestResult: false)
    let storage = MemoryNotificationStorage()
    storage.save("old-token", for: .apnsToken)
    delegate.notificationAuthorizationClient = state.client
    delegate.secureStorage = storage

    #expect(await delegate.requestNotificationPermission() == .denied)
    #expect(await delegate.requestNotificationPermission() == .denied)
    #expect(state.requestCount == 1)
    #expect(state.registrationCount == 1)
    #expect(storage.load(.apnsToken) == "old-token")
  }

  @Test("이미 거부된 권한은 다시 묻지 않는다")
  func previouslyDenied() async {
    let delegate = AppDelegate()
    let state = NotificationPermissionState(status: .denied, requestResult: true)
    delegate.notificationAuthorizationClient = state.client
    delegate.secureStorage = MemoryNotificationStorage()

    #expect(await delegate.requestNotificationPermission() == .denied)
    #expect(state.requestCount == 0)
    #expect(state.registrationCount == 1)
  }
}

@MainActor
private final class NotificationPermissionState {
  var status: UNAuthorizationStatus
  let requestResult: Bool
  var requestCount = 0
  var registrationCount = 0

  init(status: UNAuthorizationStatus, requestResult: Bool) {
    self.status = status
    self.requestResult = requestResult
  }

  var client: NotificationAuthorizationClient {
    NotificationAuthorizationClient(
      authorizationStatus: { self.status },
      requestAuthorization: {
        self.requestCount += 1
        self.status = self.requestResult ? .authorized : .denied
        return self.requestResult
      },
      registerForRemoteNotifications: {
        self.registrationCount += 1
      }
    )
  }
}

private final class MemoryNotificationStorage: SecureStorage, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [SecureStorageKey: String] = [:]

  func save(_ value: String, for key: SecureStorageKey) { lock.withLock { values[key] = value } }
  func load(_ key: SecureStorageKey) -> String? { lock.withLock { values[key] } }
  func remove(_ key: SecureStorageKey) { _ = lock.withLock { values.removeValue(forKey: key) } }
  func removeAll() { lock.withLock { values.removeAll() } }
}
