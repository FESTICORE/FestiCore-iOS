import Dependencies
import Foundation
import Testing
import UserNotifications

import FestiCoreDeviceInterface
import FestiCoreStorageInterface
@testable import FestiCore

@MainActor
struct NotificationPermissionTests {
  @Test("거부 안내는 세션에서 한 번만 표시한다")
  func settingsAlertShowsOnce() {
    var gate = NotificationSettingsAlertGate()

    let firstDenial = gate.shouldShow(for: .denied)
    let repeatedDenial = gate.shouldShow(for: .denied)
    #expect(firstDenial)
    #expect(!repeatedDenial)
  }

  @Test("허용 또는 권한 조회 실패는 안내 횟수를 소모하지 않는다")
  func settingsAlertIgnoresOtherResults() {
    var gate = NotificationSettingsAlertGate()

    let authorized = gate.shouldShow(for: .authorized)
    let unavailable = gate.shouldShow(for: .unavailable)
    let denied = gate.shouldShow(for: .denied)
    #expect(!authorized)
    #expect(!unavailable)
    #expect(denied)
  }

  @Test("앱 시작 시 저장된 APNs 토큰을 서버 등록에 전달한다")
  func registersStoredTokenOnLaunch() async {
    let service = RecordingDeviceRegistrationService()
    let delegate = withDependencies {
      $0.deviceRegistrationService = service
    } operation: {
      AppDelegate()
    }
    let storage = MemoryNotificationStorage()
    storage.save("old-token", for: .apnsToken)
    let state = NotificationPermissionState(status: .denied, requestResult: false)
    delegate.secureStorage = storage
    delegate.notificationAuthorizationClient = state.client

    delegate.configureDeviceRegistration()
    await delegate.registrationTask?.value
    delegate.liveActivityStartTokenTask?.cancel()

    let registrations = await service.registrations
    #expect(registrations.first?.apnsToken == "old-token")
    #expect(state.registrationCount == 1)
  }

  @Test("진행 중인 권한 요청 Task를 재사용한다")
  func reusesInFlightAuthorizationTask() async {
    let delegate = AppDelegate()
    let state = NotificationPermissionState(status: .notDetermined, requestResult: true)
    delegate.notificationAuthorizationClient = state.client
    let results = AsyncStream<NotificationPermissionResult>.makeStream()
    delegate.notificationAuthorizationTask = Task {
      var iterator = results.stream.makeAsyncIterator()
      return await iterator.next() ?? .unavailable
    }
    let release = Task {
      await Task.yield()
      results.continuation.yield(.denied)
      results.continuation.finish()
    }

    let result = await delegate.requestNotificationPermission()
    await release.value
    #expect(result == .denied)
    #expect(state.requestCount == 0)
    #expect(state.registrationCount == 0)
  }

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

private actor RecordingDeviceRegistrationService: DeviceRegistrationService {
  private(set) var registrations: [DeviceRegistrationMetadata] = []

  func register(_ metadata: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    registrations.append(metadata)
    return DeviceAuthorization(deviceID: "test-device", bearerToken: "test-token")
  }

  func authorization() async throws -> DeviceAuthorization? { nil }
}

private final class MemoryNotificationStorage: SecureStorage, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [SecureStorageKey: String] = [:]

  func save(_ value: String, for key: SecureStorageKey) { lock.withLock { values[key] = value } }
  func load(_ key: SecureStorageKey) -> String? { lock.withLock { values[key] } }
  func remove(_ key: SecureStorageKey) { _ = lock.withLock { values.removeValue(forKey: key) } }
  func removeAll() { lock.withLock { values.removeAll() } }
}
