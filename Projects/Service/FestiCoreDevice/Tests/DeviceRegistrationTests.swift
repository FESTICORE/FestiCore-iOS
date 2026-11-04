//
//  DeviceRegistrationTests.swift
//  FestiCoreDeviceTests
//
//  Created by FestiCore on 10/24/26.
//

import Foundation
import Testing
import Alamofire
@testable import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestiCoreStorageInterface
@testable import FestiCoreDevice

@Suite("기기 등록과 인증 정보")
struct DeviceRegistrationTests {
  private let metadata = DeviceRegistrationMetadata(
    apnsEnvironment: .sandbox,
    apnsToken: nil,
    appVersion: "1.0.0",
    osVersion: "18.0",
    locale: "ko-KR",
    timezone: "Asia/Seoul"
  )

  @Test("앱 테스트 호스트의 기본 기기 등록은 외부 요청 없이 오류를 반환한다")
  func defaultRegistrationDoesNotSucceed() async {
    await #expect(throws: TestDeviceRegistrationUnavailable.self) {
      try await DeviceRegistrationServiceDependency.testValue.register(metadata)
    }
  }

  @Test("기본 기기 인증 조회는 미등록 오류를 반환한다")
  func defaultAuthorizationDoesNotSucceed() async {
    await #expect(throws: TestDeviceRegistrationUnavailable.self) {
      _ = try await DeviceRegistrationServiceDependency.testValue.authorization()
    }
  }

  @Test("기본 설치 ID 조회는 테스트 호스트에서 오류를 반환한다")
  func defaultInstallationDeviceIDDoesNotSucceed() async {
    await #expect(throws: TestDeviceRegistrationUnavailable.self) {
      _ = try await DeviceRegistrationServiceDependency.testValue.installationDeviceID()
    }
  }

  @Test("APNs 권한이 없어도 명시적인 null 토큰으로 등록 요청한다")
  func encodesRegistrationRequest() throws {
    let request = DeviceRegistrationRequest(deviceID: UUID().uuidString, bearerToken: nil, metadata: metadata)
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

    #expect(request.path == "api/v1/devices")
    #expect(request.method == .put)
    #expect(request.authorization == .none)
    #expect(request.headers.value(for: "X-Device-Id") != nil)
    #expect(request.headers.value(for: "Authorization") == nil)
    #expect(fields["apnsToken"] is NSNull)
    #expect(fields["liveActivityPushToStartToken"] is NSNull)
    #expect(fields["apnsEnvironment"] as? String == "sandbox")
    #expect(fields["appVersion"] as? String == "1.0.0")
  }

  @Test("APNs 토큰을 받으면 기기 등록 요청에 전달한다")
  func encodesAPNsToken() throws {
    let metadata = DeviceRegistrationMetadata(
      apnsEnvironment: .sandbox,
      apnsToken: "00abff",
      appVersion: "1.0.0",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )
    let request = DeviceRegistrationRequest(deviceID: UUID().uuidString, bearerToken: nil, metadata: metadata)
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

    #expect(fields["apnsToken"] as? String == "00abff")
  }

  @Test("Live Activity 원격 시작 토큰을 기기 등록 요청에 전달한다")
  func encodesPushToStartToken() throws {
    let metadata = DeviceRegistrationMetadata(
      apnsEnvironment: .sandbox,
      apnsToken: nil,
      liveActivityPushToStartToken: "00abff",
      appVersion: "1.0.0",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )
    let request = DeviceRegistrationRequest(deviceID: UUID().uuidString, bearerToken: nil, metadata: metadata)
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

    #expect(fields["apnsToken"] is NSNull)
    #expect(fields["liveActivityPushToStartToken"] as? String == "00abff")
  }

  @Test("첫 등록 토큰을 저장하고 다음 등록에 같은 기기 ID와 토큰을 사용한다")
  func persistsDeviceAuthorization() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient()
    let service = NetworkDeviceRegistrationService(client: client, storage: storage)

    let first = try await service.register(metadata)
    #expect(UUID(uuidString: first.deviceID) != nil)
    #expect(first.bearerToken == "issued-token")
    #expect(storage.load(.deviceID) == first.deviceID)
    #expect(storage.load(.deviceAccessToken) == "issued-token")

    let second = try await service.register(metadata)
    #expect(second.deviceID == first.deviceID)
    #expect(second.bearerToken == first.bearerToken)
    #expect(try await service.authorization()?.deviceID == first.deviceID)
    #expect(client.bearerTokens == [nil, "issued-token"])
  }

  @Test("등록 실패 후에도 설치 UUID를 유지하고 토큰 없이 조회한다")
  func keepsInstallationIDAfterRegistrationFailure() async throws {
    let storage = MemoryDeviceStorage()
    let service = NetworkDeviceRegistrationService(
      client: StubDeviceClient(failsRegistration: true),
      storage: storage
    )

    await #expect(throws: FestiCoreNetworkError.self) {
      _ = try await service.register(metadata)
    }
    let deviceID = try await service.installationDeviceID()
    #expect(UUID(uuidString: deviceID) != nil)
    #expect(storage.load(.deviceID) == deviceID)
    #expect(storage.load(.deviceAccessToken) == nil)
    #expect(try await service.authorization()?.deviceID == nil)
    #expect(try await service.installationDeviceID() == deviceID)
  }

  @Test("서버 등록 전에 만든 설치 UUID를 이후 등록에도 사용한다")
  func installationIDBeforeRegistrationIsReused() async throws {
    let storage = MemoryDeviceStorage()
    let service = NetworkDeviceRegistrationService(client: StubDeviceClient(), storage: storage)

    let deviceID = try await service.installationDeviceID()
    #expect(UUID(uuidString: deviceID) != nil)
    #expect(storage.load(.deviceID) == deviceID)
    #expect(try await service.authorization()?.deviceID == nil)

    let authorization = try await service.register(metadata)
    #expect(authorization.deviceID == deviceID)
  }

  @Test("사용자 세션으로 기기를 묶은 뒤 기존 기기 토큰은 복구용으로 보관하고 세션 인증을 사용한다")
  func bindDeviceToCurrentUser() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient()
    let session = DeviceUserSession(
      id: UUID(),
      userID: "user-a"
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage,
      userSession: { session }
    )

    let registered = try await service.register(metadata)
    try await service.linkDeviceToCurrentUser()
    let bound = try #require(await service.authorization())

    #expect(bound.deviceID == registered.deviceID)
    #expect(bound.bearerToken == nil)
    #expect(bound.sessionID == session.id)
    #expect(storage.load(.deviceAccessToken) == "issued-token")
    #expect(storage.load(.deviceBoundUserID) == "user-a")
    let bind = try #require(client.captured.first { $0.path == "api/v1/devices/bind-user" })
    #expect(bind.method == .put)
    #expect(bind.authorization == .sessionBound(session.id))
    #expect(bind.deviceToken == "issued-token")
    #expect(bind.bearerToken == nil)
    #expect(bind.parameters == nil)
  }

  @Test("로그아웃 전 바인딩을 풀면 새 익명 토큰으로 복귀한다")
  func unbindDevice() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient()
    let session = DeviceUserSession(
      id: UUID(),
      userID: "user-a"
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage,
      userSession: { session }
    )
    _ = try await service.register(metadata)
    try await service.linkDeviceToCurrentUser()

    try await service.unbindCurrentUser()

    #expect(storage.load(.deviceBoundUserID) == nil)
    #expect(storage.load(.deviceAccessToken) == "new-device-token")
    #expect(try await service.authorization()?.bearerToken == "new-device-token")
    let unbind = try #require(client.captured.last)
    #expect(unbind.path == "api/v1/devices/bind-user")
    #expect(unbind.method == .delete)
    #expect(unbind.authorization == .sessionBound(session.id))
    #expect(unbind.deviceToken == nil)
    #expect(UUID(uuidString: try #require(unbind.unbindKey)) != nil)
    #expect(storage.load(.deviceUnbindKey) == nil)
  }

  @Test(
    "같은 프로세스에서 재로그인하면 동일 APNs와 시작 토큰을 한 번 복원한다",
    arguments: [false, true]
  )
  func rebindRestoresUnchangedPushTokensOnce(recoverExpiredSession: Bool) async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient()
    let session = DeviceUserSession(
      id: UUID(),
      userID: "user-a"
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage,
      userSession: { session }
    )
    let tokens = DeviceRegistrationMetadata(
      apnsEnvironment: .sandbox,
      apnsToken: "test-apns",
      liveActivityPushToStartToken: "test-start",
      appVersion: "1.0.0",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )
    _ = try await service.register(tokens)
    try await service.linkDeviceToCurrentUser()
    #expect(client.captured.filter { $0.path == "api/v1/devices" }.count == 1)
    if recoverExpiredSession {
      try await service.recoverBoundDevice()
    } else {
      try await service.unbindCurrentUser()
    }
    try await service.linkDeviceToCurrentUser()
    try await service.linkDeviceToCurrentUser()

    let registrations = client.captured.filter { $0.path == "api/v1/devices" }
    #expect(registrations.count == 2)
    let restored = try #require(registrations.last)
    #expect(restored.authorization == .sessionBound(session.id))
    let body = try #require(restored.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
    #expect(fields["apnsToken"] as? String == tokens.apnsToken)
    #expect(fields["liveActivityPushToStartToken"] as? String == tokens.liveActivityPushToStartToken)
  }

  @Test("동시에 바인딩해도 진행 중인 토큰 복원 요청을 공유한다")
  func concurrentRebindSharesPushTokenRestoration() async throws {
    let started = AsyncStream<Void>.makeStream()
    let resume = AsyncStream<Void>.makeStream()
    defer { started.continuation.finish(); resume.continuation.finish() }
    let client = StubDeviceClient(beforeTokenRestoration: {
      started.continuation.yield(())
      for await _ in resume.stream { break }
    })
    let session = DeviceUserSession(
      id: UUID(),
      userID: "user-a"
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: MemoryDeviceStorage(),
      userSession: { session }
    )
    _ = try await service.register(metadata)
    try await service.linkDeviceToCurrentUser()
    try await service.unbindCurrentUser()

    async let first: Void = service.linkDeviceToCurrentUser()
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()
    async let second: Void = service.linkDeviceToCurrentUser()
    await Task.yield()
    resume.continuation.yield(())
    resume.continuation.finish()
    _ = try await (
      first,
      second
    )
    #expect(client.captured.filter { $0.path == "api/v1/devices" }.count == 2)
  }

  @Test("재로그인 토큰 복원 실패는 다음 바인딩에서 재시도한다")
  func rebindRetriesFailedPushTokenRestoration() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient(failsRegistrationAfterUnbindOnce: true)
    let session = DeviceUserSession(
      id: UUID(),
      userID: "user-a"
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage,
      userSession: { session }
    )
    _ = try await service.register(metadata)
    try await service.linkDeviceToCurrentUser()
    try await service.unbindCurrentUser()
    await #expect(throws: FestiCoreNetworkError.self) { try await service.linkDeviceToCurrentUser() }
    try await service.linkDeviceToCurrentUser()
    try await service.linkDeviceToCurrentUser()

    #expect(client.captured.filter { $0.path == "api/v1/devices" }.count == 3)
    #expect(client.captured.filter { $0.path == "api/v1/devices/bind-user" && $0.method == .put }.count == 2)
  }

  @Test("해제 응답을 잃으면 저장된 동일 재시도 키로 다시 요청한다")
  func unbindRetryUsesSameKey() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient(failsUnbindOnce: true)
    let session = DeviceUserSession(
      id: UUID(),
      userID: "user-a"
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage,
      userSession: { session }
    )
    _ = try await service.register(metadata)
    try await service.linkDeviceToCurrentUser()

    await #expect(throws: FestiCoreNetworkError.self) { try await service.unbindCurrentUser() }
    let pendingKey = try #require(storage.load(.deviceUnbindKey))
    try await service.unbindCurrentUser()

    let unbinds = client.captured.filter { $0.method == .delete }
    #expect(unbinds.count == 2)
    #expect(unbinds.allSatisfy { $0.unbindKey == pendingKey })
    #expect(storage.load(.deviceBoundUserID) == nil)
  }

  @Test("다른 계정으로 전환되면 이전 계정 기기 인증을 반환하지 않는다")
  func changedUserCannotReuseBoundDevice() async throws {
    let storage = MemoryDeviceStorage()
    storage.save(
      UUID().uuidString,
      for: .deviceID
    )
    storage.save(
      "user-a",
      for: .deviceBoundUserID
    )
    let service = NetworkDeviceRegistrationService(
      client: StubDeviceClient(),
      storage: storage,
      userSession: { DeviceUserSession(
        id: UUID(),
        userID: "user-b"
      ) }
    )

    #expect(try await service.authorization()?.deviceID == nil)
    await #expect(throws: DeviceRegistrationError.deviceNotRegistered) {
      try await service.linkDeviceToCurrentUser()
    }
  }

  @Test("세션이 만료되어도 기존 기기 토큰과 재시도 키로 연결을 해제한다")
  func recoverAfterSessionExpiry() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient()
    storage.save(
      UUID().uuidString,
      for: .deviceID
    )
    storage.save(
      "user-a",
      for: .deviceBoundUserID
    )
    storage.save(
      "issued-token",
      for: .deviceAccessToken
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage
    )

    try await service.recoverBoundDevice()

    #expect(storage.load(.deviceBoundUserID) == nil)
    #expect(storage.load(.deviceAccessToken) == "new-device-token")
    let request = try #require(client.captured.last)
    #expect(request.path == "api/v1/devices/bind-user/recover")
    #expect(request.method == .delete)
    #expect(request.authorization == .none)
    #expect(request.bearerToken == "issued-token")
    #expect(UUID(uuidString: try #require(request.unbindKey)) != nil)
  }

  @Test("복구 응답을 잃은 뒤에는 동일 키로 기기 토큰 없이 재시도한다")
  func recoverRetryWithoutOldToken() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient(rejectsRecoveryBearer: true)
    storage.save(
      UUID().uuidString,
      for: .deviceID
    )
    storage.save(
      "user-a",
      for: .deviceBoundUserID
    )
    storage.save(
      "issued-token",
      for: .deviceAccessToken
    )
    let service = NetworkDeviceRegistrationService(
      client: client,
      storage: storage
    )

    try await service.recoverBoundDevice()

    let recoveries = client.captured.filter { $0.path == "api/v1/devices/bind-user/recover" }
    #expect(recoveries.count == 2)
    #expect(recoveries[0].bearerToken == "issued-token")
    #expect(recoveries[1].bearerToken == nil)
    #expect(recoveries[0].unbindKey == recoveries[1].unbindKey)
    #expect(storage.load(.deviceAccessToken) == "new-device-token")
    #expect(storage.load(.deviceUnbindKey) == nil)
  }
}

private final class MemoryDeviceStorage: SecureStorage, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [SecureStorageKey: String] = [:]

  func save(_ value: String, for key: SecureStorageKey) { lock.withLock { values[key] = value } }
  func load(_ key: SecureStorageKey) -> String? { lock.withLock { values[key] } }
  func remove(_ key: SecureStorageKey) { _ = lock.withLock { values.removeValue(forKey: key) } }
  func removeAll() { lock.withLock { values.removeAll() } }
}

private final class StubDeviceClient: FestiCoreRequestClient, @unchecked Sendable {
  private let lock = NSLock()
  private let failsRegistration: Bool
  private var failsUnbindOnce: Bool
  private let rejectsRecoveryBearer: Bool
  private var failsRegistrationAfterUnbindOnce: Bool
  private var hasUnbound = false
  private let beforeTokenRestoration: (@Sendable () async -> Void)?
  struct Captured {
    let path: String
    let method: HTTPMethod
    let authorization: FestiCoreAuthorization
    let deviceID: String
    let bearerToken: String?
    let deviceToken: String?
    let unbindKey: String?
    let parameters: (any Encodable & Sendable)?
  }
  private var requests: [Captured] = []

  init(
    failsRegistration: Bool = false,
    failsUnbindOnce: Bool = false,
    rejectsRecoveryBearer: Bool = false,
    failsRegistrationAfterUnbindOnce: Bool = false,
    beforeTokenRestoration: (@Sendable () async -> Void)? = nil
  ) {
    self.failsRegistration = failsRegistration
    self.failsUnbindOnce = failsUnbindOnce
    self.rejectsRecoveryBearer = rejectsRecoveryBearer
    self.failsRegistrationAfterUnbindOnce = failsRegistrationAfterUnbindOnce
    self.beforeTokenRestoration = beforeTokenRestoration
  }

  var bearerTokens: [String?] { lock.withLock { requests.map { $0.bearerToken } } }
  var captured: [Captured] { return lock.withLock { requests } }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    if failsRegistration { throw .request(.invalidURL) }
    let deviceID = request.headers.value(for: "X-Device-Id") ?? ""
    let bearer = request.headers.value(for: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
    let shouldFail = lock.withLock {
      requests.append(Captured(
        path: request.path,
        method: request.method,
        authorization: request.authorization,
        deviceID: deviceID,
        bearerToken: bearer,
        deviceToken: request.headers.value(for: "X-Device-Access-Token"),
        unbindKey: request.headers.value(for: "X-Device-Unbind-Key"),
        parameters: request.parameters
      ))
      if request.method == .delete { hasUnbound = true }
      if request.path == "api/v1/devices", hasUnbound, failsRegistrationAfterUnbindOnce {
        failsRegistrationAfterUnbindOnce = false
        return true
      }
      if request.method == .delete && failsUnbindOnce {
        failsUnbindOnce = false
        return true
      }
      return false
    }
    if shouldFail { throw .request(.invalidURL) }
    if request.path == "api/v1/devices", lock.withLock({ hasUnbound }) {
      await beforeTokenRestoration?()
    }
    if request.path == "api/v1/devices/bind-user/recover", bearer != nil, rejectsRecoveryBearer {
      throw .response(ResponseError(httpStatus: 401))
    }
    let payload: String
    if request.path == "api/v1/devices/bind-user/recover" {
      payload = "{\"deviceId\":\"\(deviceID)\",\"userId\":null,\"deviceAccessToken\":\"new-device-token\"}"
    } else if request.path == "api/v1/devices/bind-user" {
      payload = request.method == .put
        ? "{\"deviceId\":\"\(deviceID)\",\"userId\":\"user-a\"}"
        : "{\"deviceId\":\"\(deviceID)\",\"userId\":null,\"deviceAccessToken\":\"new-device-token\"}"
    } else {
      let tokenField = bearer == nil ? "\"deviceAccessToken\":\"issued-token\"," : ""
      payload = "{\(tokenField)\"deviceId\":\"\(deviceID)\"}"
    }
    let response = Data("{\"code\":\"SUCCESS\",\"message\":\"성공\",\"data\":\(payload)}".utf8)
    do { return try JSONDecoder().decode(T.self, from: response) }
    catch { throw .decoding(.failed(error)) }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    try await send(request, as: R.Response.self)
  }

  func sendResponse<R: FestiCoreDataRequest>(_: R) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}
